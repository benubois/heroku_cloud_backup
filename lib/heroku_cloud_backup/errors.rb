# encoding: utf-8

module HerokuCloudBackup
  module Errors
    class Error < StandardError; end
    class NotFound < HerokuCloudBackup::Errors::Error; end
    class ConnectionError < HerokuCloudBackup::Errors::Error; end
    class UploadError < HerokuCloudBackup::Errors::Error; end
    class NoBackups < HerokuCloudBackup::Errors::Error; end
    class Forbidden < HerokuCloudBackup::Errors::Error; end
  end
end
