
module LigatureYourName
  if Rails.env.development?
    TEMPFILE_DIR = Rails.root + "tmp"
  else
    TEMPFILE_DIR = Pathname("/tmp")
  end
end
