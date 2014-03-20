module BrowseEverything
  module Driver
    class Box < Base
      require 'ruby-box'

      def icon
        'cloud'
      end

      def validate_config
        unless config[:client_id]
          raise BrowseEverything::InitializationError, "Box driver requires a :client_id argument"
        end
        unless config[:client_secret]
          raise BrowseEverything::InitializationError, "Box driver requires a :client_secret argument"
        end
      end

      def contents(path='')
        path.sub!(/^[\/.]+/,'')
        result = []
        unless path.empty?
          result << BrowseEverything::FileEntry.new(
              Pathname(path).join('..'),
              '', '..', 0, Time.now, true
          )
        end
        folder = box_client { |c| path.empty? ? c.root_folder : c.folder(path) }
        result += folder.items.collect do |f|
        BrowseEverything::FileEntry.new(
            File.join(path,f.name),#id here
            "#{self.key}:#{File.join(path,f.name)}",#single use link
            f.name,
            f.size,
            f.created_at,
            f.type == 'folder'
        )
        end
        result
      end

      def link_for(path)
        file = box_client { |c| c.file(path) }
        download_url = file.download_url
        auth_header = {'Authorization' => "Bearer #{@token.token}"}
        extras = { auth_header: auth_header, expires: 1.hour.from_now , file_name:file.name }
        [download_url,extras]
      end

      def details(f)
      end

      def auth_link
        callback = connector_response_url(config[:url_options])
        oauth_client.authorize_url(callback.to_s)
      end

      def authorized?
        #false
        @token.present? and @token.token.present?
      end

      def connect(params,data)
        @token = oauth_client.get_access_token(params[:code])
      end

      private
      def oauth_client
        session = RubyBox::Session.new({
                                           client_id: config[:client_id],
                                           client_secret: config[:client_secret]
                                       })

         session
        #todo error checking here
      end

      def box_client
        session = RubyBox::Session.new({
                                           client_id: config[:client_id],
                                           client_secret: config[:client_secret],
                                           access_token: @token.token
                                       })
        result = yield(RubyBox::Client.new(session))
        @token = session.refresh_token(@token.refresh_token)
        result
      end

    end

  end
end