
require "font_creator"

class FontsController < ApplicationController
  TEMPFILE_DIR = LigatureYourName::TEMPFILE_DIR

  def create
    permitted = params.require(:font_data).permit(ligature_list: [:ligature, :deco_type, :bold])
    converted_params = {
      "ligature_list" => permitted["ligature_list"].map{ |i|
        next nil if i["ligature"].blank?
        next {
          "ligature" => i["ligature"],
          "deco_type" => i["deco_type"].to_i,
          "bold" => (i["bold"] == "true")
        }
      }.select(&:present?),
      "fonttype" => "truetype"
    }
    # obj = {
    #   "ligature_list" => [
    #     {
    #       "ligature" => "山田",
    #       "deco_type" => 3,
    #       "bold" => true
    #     }
    #   ],
    #   "fonttype" => "truetype"
    # }

    font_creator = FontCreator.new(converted_params, TEMPFILE_DIR)
    font_creator.create_json_file
    FontforgeJob.perform_later(Marshal.dump(font_creator))
    @font_id = font_creator.id

    redirect_to font_path(@font_id)
  end

  def show
    id = params[:id].to_s
    state_or_filename = FontCreator.font_state(id, TEMPFILE_DIR)

    @complete = false
    case state_or_filename
    when :invalid
      raise ActionController::RoutingError.new("Font Not Found")
    when String
      @font_id = id
      @complete = true
    else
      @font_id = id
    end
  end

  def font_file
    id = params[:id]
    state_or_filename = FontCreator.font_state(id, TEMPFILE_DIR)

    case state_or_filename
    when :invalid, :creating, :prepared
      raise ActionController::RoutingError.new('Not Found') unless filepath.file?
    when String
      send_file(TEMPFILE_DIR + state_or_filename, filename: "LigatureYourName.ttf", content_type: "application/octet-stream")
    end
  end
end
