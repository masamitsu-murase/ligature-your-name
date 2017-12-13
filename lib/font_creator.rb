require "pathname"
require "json"
require "fileutils"
require "digest/sha1"

class FontCreator
  MAX_LIGATURE_COUNT = 20
  TEMPFILE_NAME_SEPARATOR = "__"
  RAND = Random.new
  SCRIPT_PATH = (Pathname(__dir__).parent + "converter").cleanpath
  ROOT_DIR = Pathname(__dir__).parent.cleanpath
  FONT_FILENAME = "LigatureYourName.ttf"

  def initialize(ligature_list_obj, temp_dir, script_path=SCRIPT_PATH)
    check_ligature_list(ligature_list_obj)
    @ligature_list_obj = ligature_list_obj
    @json_data = JSON.generate(ligature_list_obj)
    @id = font_id(@json_data)
    @temp_dir = Pathname(temp_dir.to_s)
    @timestamp = Time.now.to_f.to_s
    @script_path = script_path
  end
  attr_reader :id, :temp_dir, :timestamp

  def create_json_file
    File.open(json_filepath, "w") do |file|
      file.puts @json_data
    end
  end

  def create_font
    ret = system("fontforge -nosplash -lang=py -script create_ligature.py #{json_filepath} #{font_temp_filepath}", chdir: @script_path)
    raise "fontforge failed" unless ret

    Bundler.with_clean_env do
        ret = system("bundle exec ruby converter/zipper.rb #{font_temp_filepath} #{FONT_FILENAME} #{zip_filepath}", chdir: ROOT_DIR.to_s)
        raise "zip file error" unless ret
    end
    FileUtils.rm_f(font_temp_filepath)
  end

  def clear
    [json_filepath, zip_filepath, font_temp_filepath].each do |filepath|
      FileUtils.rm_f(filepath) if File.file? filepath
    end
  end

  def temp_filepath(prefix, suffix)
    @temp_dir + [prefix, @id, @timestamp, suffix].join(TEMPFILE_NAME_SEPARATOR)
  end

  def zip_filepath
    temp_filepath("zip", ".zip")
  end

  def json_filepath
    temp_filepath("json", ".json")
  end

  def font_temp_filepath
    temp_filepath("tmpfnt", ".ttf")
  end

  def font_id(json_data)
    json_data.bytesize.to_s(16) + Digest::SHA1.hexdigest(json_data) + RAND.rand(0x10000).to_s(16).rjust(4, "0")
  end

  def check_ligature_list(obj)
    ligature_list = obj["ligature_list"]
    raise ArgumentError.new("ligature_list is not an Array") unless ligature_list.kind_of? Array
    raise ArgumentError.new("ligature_list is not valid length") unless ligature_list.size > 0 && ligature_list.size < MAX_LIGATURE_COUNT

    ligature_list.all? do |ligature|
      raise ArgumentError.new("ligature error") unless ligature.kind_of? Hash
      raise ArgumentError.new("keys error") unless ligature.keys.sort == ["bold", "deco_type", "ligature"]
      raise ArgumentError.new("deco_type error") unless [0, 1, 2, 3, 4].include? ligature["deco_type"]
      raise ArgumentError.new("ligature") unless ligature["ligature"].kind_of?(String) && ligature["ligature"].size > 0
    end

    raise ArgumentError.new("fonttype error") unless ["truetype"].include? obj["fonttype"]
  end

  class << self
    def font_state(id, temp_dir)
      temp_dir = Pathname(temp_dir)
      font_files = find_font_files_helper(temp_dir, ["*", id, "*", "*"].join(TEMPFILE_NAME_SEPARATOR))
      return :invalid if font_files.size == 0

      font_file = font_files[font_files.keys.max]
      if font_file["zip"] && File.file?(temp_dir + font_file["zip"])
        return font_file["zip"]
      elsif font_file["tmpfnt"] && File.file?(temp_dir + font_file["tmpfnt"])
        return :creating
      elsif font_file["json"] && File.file?(temp_dir + font_file["json"])
        return :prepared
      else
        return :invalid
      end
    end

    def find_font_files(temp_dir)
      temp_dir = Pathname(temp_dir)
      find_font_files_helper(temp_dir, "*")
    end

    def find_font_files_helper(temp_dir, pattern)
      font_files_hash = {}
      Dir.glob(temp_dir + pattern) do |path|
        file = File.basename(path)
        type, id, timestamp, suffix = file.split(TEMPFILE_NAME_SEPARATOR)
        next unless suffix

        key = id + TEMPFILE_NAME_SEPARATOR + timestamp
        if font_files_hash.key?(key)
          hash = font_files_hash[key]
        else
          hash = font_files_hash[key] = { "timestamp" => timestamp.to_f, "id" => id }
        end

        case type
        when "zip"
          hash["zip"] = file
        when "json"
          hash["json"] = file
        when "tmpfnt"
          hash["tmpfnt"] = file
        end
      end

      font_files_hash
    end

    def remove_old_files(temp_dir, max_count=40, duration_s=2*60*60)
      temp_dir = Pathname(temp_dir)
      font_files_hash = find_font_files(temp_dir)
      sorted_font_files = font_files_hash.values.sort_by{ |i| i["timestamp"] }

      base = Time.now.to_i - duration_s

      if sorted_font_files.size > max_count
        sorted_font_files[0, sorted_font_files.size - max_count].each do |item|
          ["zip", "json", "tmpfnt"].each do |type|
            FileUtils.rm_f(item[type]) if item[type] && File.file?(item[type])
          end
        end
        sorted_font_files = sorted_font_files[(sorted_font_files.size - max_count) .. -1]
      end

      sorted_font_files.each do |item|
        if item["timestamp"] < base
          ["zip", "json", "tmpfnt"].each do |type|
            FileUtils.rm_f(temp_dir + item[type]) if item[type] && File.file?(temp_dir + item[type])
          end
        end
      end
    end
  end
end
