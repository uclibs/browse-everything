require 'dropbox_sdk'

module BrowseEverything
  module Driver
    class Dropbox < Base
      def icon
        'dropbox'
      end

      def validate_config
        unless [:app_key, :app_secret].all? { |key| config[key].present? }
          raise BrowseEverything::InitializationError, 'Dropbox driver requires :app_key and :app_secret'
        end
      end

      def contents(path = '', _user = '')
        path.sub!(/^[\/.]+/, '')
        result = []
        unless path.empty?
          result << BrowseEverything::FileEntry.new(
            Pathname(path).join('..'),
            '', '..', 0, Time.now, true
          )
        end
        result += client.metadata(path)['contents'].collect do |info|
          path = info['path']
          BrowseEverything::FileEntry.new(
            path,
            [key, path].join(':'),
            File.basename(path),
            info['bytes'],
            Time.parse(info['modified']),
            info['is_dir']
          )
        end
        result
      end

      def link_for(path)
        [client.media(path)['url'], { expires: 4.hours.from_now, file_name: File.basename(path), file_size: client.metadata(path)['bytes'].to_i }]
      end

      def details(path)
        contents(path).first
      end

      def auth_link
        [auth_flow.start('dropbox'), @csrf]
      end

      def connect(params, data)
        @csrf = data
        @token, _user, _state = auth_flow.finish(params)
        @token
      end

      def authorized?
        token.present?
      end

      private

      def auth_flow
        @csrf ||= {}
        DropboxOAuth2Flow.new(config[:app_key], config[:app_secret], callback.to_s, @csrf, 'token')
      end

      def client
        DropboxClient.new(token)
      end
    end
  end
end
