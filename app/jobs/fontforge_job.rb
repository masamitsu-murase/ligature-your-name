class FontforgeJob < ApplicationJob
  queue_as :font_forge

  def perform(font_creator_str)
    font_creator = Marshal.load(font_creator_str)
    FontCreator.remove_old_files(font_creator.temp_dir)
    begin
      font_creator.create_font
    rescue => e
      Rails.logger.info(e.to_s)
      ActionCable.server.broadcast("font_#{font_creator.id}", event: "error")
      font_creator.clear
      return
    end

    ActionCable.server.broadcast("font_#{font_creator.id}", event: "created")
  end
end
