module BrowseEverything
  module Driver
    class Box < Base
      require 'ruby-box'

      ITEM_LIMIT = 99999

      def icon
        'cloud'
      end

      def validate_config
        unless config[:client_id]
          raise BrowseEverything::InitializationError, 'Box driver requires a :client_id argument'
        end
        unless config[:client_secret]
          raise BrowseEverything::InitializationError, 'Box driver requires a :client_secret argument'
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
        folder = path.empty? ? box_client.root_folder : box_client.folder(path)
        result += folder.items(ITEM_LIMIT, 0, %w(name size created_at)).collect do |f|
          BrowseEverything::FileEntry.new(
            File.join(path, f.name), # id here
            "#{key}:#{File.join(path, f.name)}", # single use link
            f.name,
            f.size,
            f.created_at,
            f.type == 'folder'
          )
        end
        result
      end

      def link_for(path)
        file = box_client.file(path)
        download_url = file.download_url
        auth_header = { 'Authorization' => "Bearer #{@token}" }
        extras = { auth_header: auth_header, expires: 1.hour.from_now, file_name: file.name, file_size: file.size.to_i }
        [download_url, extras]
      end

      def auth_link
        oauth_client.authorize_url(callback.to_s)
      end

      def authorized?
        @token.present? && @token['token'].present?
      end

      def connect(params, _data)
        access_token = oauth_client.get_access_token(params[:code])
        @token = { 'token' => access_token.token, 'refresh_token' => access_token.refresh_token }
      end

      private

      def oauth_client
        RubyBox::Session.new(client_id: config[:client_id],
                             client_secret: config[:client_secret])
        # TODO: error checking here
      end

      def token_expired?(token)
        return false unless @token.present? && @token['token'].present?
        new_session = RubyBox::Session.new(
          client_id: config[:client_id],
          client_secret: config[:client_secret],
          access_token: token
        )
        result = new_session.get("#{RubyBox::API_URL}/users/me")
        result['status'] != 200
      rescue RubyBox::AuthError => e
        Rails.logger.error("AuthError occured when checking token. Exception #{e.class.name} : #{e.message}. token as expired and need to refresh it")
        return true
      end

      def refresh_token
        refresh_token = @token['refresh_token']
        token = @token['token']
        session = RubyBox::Session.new(
          client_id: config[:client_id],
          client_secret: config[:client_secret],
          access_token: token
        )
        access_token = session.refresh_token(refresh_token)
        @token = { 'token' => access_token.token, 'refresh_token' => access_token.refresh_token }
      end

      def box_client
        refresh_token if token_expired?(@token['token'])
        token = @token['token']
        refresh_token = @token['refresh_token']
        session = RubyBox::Session.new(
          client_id: config[:client_id],
          client_secret: config[:client_secret],
          access_token: token,
          refresh_token: refresh_token
        )
        RubyBox::Client.new(session)
      end
    end
  end
end
