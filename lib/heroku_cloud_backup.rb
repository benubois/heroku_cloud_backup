# encoding: utf-8

require 'fog'
require 'open-uri'
require "heroku"
require "heroku/client/pgbackups"
require 'heroku_cloud_backup/errors'
require 'heroku_cloud_backup/railtie'
require 'heroku_cloud_backup/version'

module HerokuCloudBackup
  class << self
    def execute(index = 0)
      log "heroku:backup started"

      b = client.get_backups.last
      raise HerokuCloudBackup::Errors::NoBackups.new("You don't have any pgbackups. Please run heroku pgbackups:capture first.") if b.empty?

      begin
        directory = connection.directories.get(bucket_name)
      rescue Excon::Errors::Forbidden
        raise HerokuCloudBackup::Errors::Forbidden.new("You do not have access to this bucket name. It's possible this bucket name is already owned by another user. Please check your credentials (access keys) or select a different bucket name.")
      end

      if !directory
        directory = connection.directories.create(:key => bucket_name)
      end
      
      public_urls = b["public_url"].split("\n")
      created_at = DateTime.parse b["created_at"]
      db_name = b["from_name"]
      base_name = created_at.strftime('%Y-%m-%d-%H%M%S')
      
      if public_urls[index]
        begin
          name = "#{base_name}_#{index}.dump"
          log "creating #{@backup_path}/#{b["from_name"]}/#{name}"
          directory.files.create(:key => "#{backup_path}/#{b["from_name"]}/#{name}", :body => open(public_urls[index]))
        rescue Exception => e
          raise HerokuCloudBackup::Errors::UploadError.new(e.message)
        end
      end

      if public_urls[index + 1]
        execute(index + 1)
      else
        log "heroku:backup complete"
      end
    end

    def connection=(connection)
      @connection = connection
    end

    def connection
      return @connection if @connection
      self.connection =
        begin
          case provider
          when 'aws'
            Fog::Storage.new(:provider => 'AWS',
                             :aws_access_key_id     => key1,
                             :aws_secret_access_key => key2
                             )
          when 'rackspace'
            Fog::Storage.new(:provider => 'Rackspace',
                             :rackspace_username => key1,
                             :rackspace_api_key  => key2
                             )
          when 'google'
            Fog::Storage.new(:provider => 'Google',
                             :google_storage_secret_access_key => key1,
                             :google_storage_access_key_id     => key2
                             )
          else
            raise "Your provider was invalid. Valid values are 'aws', 'rackspace', or 'google'"
          end
        rescue => error
          raise HerokuCloudBackup::Errors::ConnectionError.new("There was an error connecting to your provider. #{error}")
        end
    end

    def client
      @client ||= ::Heroku::Client::Pgbackups.new(backups_url)
    end

    private
    def backups_url
      ENV["PGBACKUPS_URL"] || raise(HerokuCloudBackup::Errors::NotFound.new("'PGBACKUPS_URL' environment variable not found."))
    end

    def bucket_name
      ENV['HCB_BUCKET'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_BUCKET' config variable."))
    end

    def backup_path
      ENV['HCB_PREFIX'] || "db"
    end

    def provider
      ENV['HCB_PROVIDER'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_PROVIDER' config variable."))
    end

    def key1
      ENV['HCB_KEY1'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_KEY1' config variable."))
    end

    def key2
      ENV['HCB_KEY2'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_KEY2' config variable."))
    end

    def log(message)
      puts "[#{Time.now}] #{message}"
    end

  end
end
