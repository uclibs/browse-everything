module BrowseEverything
  module Driver
    class GoogleDrive < Base

      require 'google/api_client'

      def icon
        'google-plus-sign'
      end

      def validate_config
        unless config[:client_id]
          raise BrowseEverything::InitializationError, "GoogleDrive driver requires a :client_id argument"
        end
        unless config[:client_secret]
          raise BrowseEverything::InitializationError, "GoogleDrive driver requires a :client_secret argument"
        end
      end

      def contents(path='')
        page_token = nil
        files = []
        begin
          default_params = execute_params(path: path, page_token: page_token)
          api_result = oauth_client.execute( api_method: drive.files.list, parameters: default_params )
          response = JSON.parse(api_result.response.body)
          page_token = response["nextPageToken"]
          response["items"].each do |file|
            if path.blank?
              if file["parents"].blank? or file["parents"].any?{|p| p["isRoot"] }
                files << details(file, path)
              end
            else
              files << details(file, path)
            end
          end
        end while !page_token.blank?
        files.compact
      end

      def details(file, path='')
        BrowseEverything::FileEntry.new(
          file["id"],
          "#{self.key}:#{file["id"]}",
          file["title"],
          (file["fileSize"] || 0),
          Time.parse(file["modifiedDate"]),
          file["mimeType"] == "application/vnd.google-apps.folder",
          file["mimeType"] == "application/vnd.google-apps.folder" ?
                                "directory" :
                                file["mimeType"]
        ) if file["downloadUrl"] or file["mimeType"] == "application/vnd.google-apps.folder"
      end

      def link_for(id)
        api_result = oauth_client.execute(api_method: drive.files.get, parameters: {fileId: id})
        download_url = JSON.parse(api_result.response.body)["downloadUrl"]
        auth_header = "Authorization: Bearer #{oauth_client.authorization.access_token.to_s}"
        [download_url,auth_header]
      end

      def auth_link
        oauth_client.authorization.authorization_uri.to_s
      end

      def authorized?
        @token.present?
      end

      def connect(params, data)
        oauth_client.authorization.code = params[:code]
        @token = oauth_client.authorization.fetch_access_token!
      end

      def execute_params(opts={})
        params = {}
        unless opts[:path].blank?
          params[:q] = "'#{opts[:path]}' in parents"
        end
        unless opts[:page_token].blank?
          params[:pageToken] = opts[:page_token]
        end
        params
      end

      def drive
        oauth_client.discovered_api('drive', 'v2')
      end

      private

      def oauth_client
        if @client.nil?
          callback = connector_response_url(config[:url_options])
          @client = Google::APIClient.new
          @client.authorization.client_id = config[:client_id]
          @client.authorization.client_secret = config[:client_secret]
          @client.authorization.scope = "https://www.googleapis.com/auth/drive"
          @client.authorization.redirect_uri = callback
          @client.authorization.update_token!(@token) if @token.present?
        end
        #todo error checking here
        @client
      end

    end

  end
end