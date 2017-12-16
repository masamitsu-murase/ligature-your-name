
require "font_creator"

class FontsController < ApplicationController
  TEMPFILE_DIR = LigatureYourName::TEMPFILE_DIR
  MAX_LIGATURE_SIZE = 10

  def create
    params_hash = params.to_unsafe_hash
    ligature_list = MAX_LIGATURE_SIZE.to_enum(:times).map{ |i| params_hash["font_data"]["ligature_list"][i.to_s] }.select(&:present?)
    converted_params = {
      "ligature_list" => ligature_list.map{ |i|
        next nil if i["ligature"].blank?
        next {
          "ligature" => i["ligature"],
          "deco_type" => i["deco_type"].to_i,
          "bold" => (i["bold"] == "true")
        }
      }.select(&:present?)
    }
    # obj = {
    #   "ligature_list" => [
    #     {
    #       "ligature" => "山田",
    #       "deco_type" => 3,
    #       "bold" => true
    #     }
    #   ],
    #   "font_type" => "ttf"
    # }

    font_type = (params[:font_type] == "ttf" ? "ttf" : "otf")
    font_creator = FontCreator.new(converted_params, TEMPFILE_DIR, font_type)
    font_creator.create_json_file
    FontforgeJob.perform_later(Marshal.dump(font_creator))
    @font_id = font_creator.id

    redirect_to font_path(@font_id, font_type: font_creator.font_type)
  rescue
    flash[:error] = "エラーが発生しました。もう一度、試してください。"
    redirect_to new_font_path
  end

  def show
    id = params[:id].to_s
    @font_type = (params[:font_type].to_s == "ttf" ? "ttf" : "otf")
    state_or_filename = FontCreator.font_state(id, TEMPFILE_DIR)

    @complete = false
    case state_or_filename
    when :invalid
      flash[:error] = "ファイルが見つかりません。もう一度、試してください。"
      redirect_to new_font_path
    when String
      @font_id = id
      @complete = true
    else
      @font_id = id
    end
  end

  def font_file
    id = params[:id]
    font_type = (params[:font_type].to_s == "ttf" ? "ttf" : "otf")
    state_or_filename = FontCreator.font_state(id, TEMPFILE_DIR)

    case state_or_filename
    when :invalid, :creating, :prepared
      flash[:error] = "ファイルが見つかりません。もう一度、試してください。"
      redirect_to new_font_path
    when String
      filepath = TEMPFILE_DIR + state_or_filename
      send_file(filepath, filename: "LigatureYourName.#{font_type}", content_type: "application/octet-stream")
    end
  end
end
