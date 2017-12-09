
require "font_creator"

class FontChannel < ApplicationCable::Channel
  TEMPFILE_DIR = LigatureYourName::TEMPFILE_DIR

  def subscribed
    # stream_from "some_channel"
    @id = params[:id]
    stream_from "font_#{@id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def check
    Rails.logger.info @id

    state_or_filename = FontCreator.font_state(@id, TEMPFILE_DIR)

    case state_or_filename
    when :invalid
      ActionCable.server.broadcast("font_#{@id}", event: "error")
    when :prepared, :creating
      ActionCable.server.broadcast("font_#{@id}", event: "creating")
    when String
      ActionCable.server.broadcast("font_#{@id}", event: "created")
    end
  end
end
