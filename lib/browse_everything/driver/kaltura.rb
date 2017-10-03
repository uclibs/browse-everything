module BrowseEverything
  module Driver
    class Kaltura < Base
      require 'kaltura'

      def icon
        'kaltura'
      end

      def validate_config
        unless [:partner_id,:administrator_secret,:service_url].all? { |key| config[key].present? }
          raise BrowseEverything::InitializationError, "Kaltura driver requires :partner_id, :administrator_secret, and :service_url"
        end
      end

      def contents(path='')
        result = []
        @options = { :filter => { :creatorIdEqual => $current_user, :orderBy => "+name"  }, :pager => {:pageSize => 1000}  }
        @session = ::Kaltura::Session.start
        begin
          @@entries = ::Kaltura::MediaEntry.list(@options)
          @@entries.each do |item|
            next if item.downloadUrl.nil?
            item.location = item.downloadUrl.sub('https:', 'kaltura:')
            item.mtime = Time.at(item.updatedAt.to_i)
            item.duration = item.duration + " sec"
            result.push(item)
          end
          result
        rescue
          result
        end
      end

      def link_for(path)
        correct_path = path.sub('//', 'https://')
        file_list = @@entries
        extras = {file_name: ''}
        file_list.each do |file|
          if file.downloadUrl == correct_path
            extras[:file_name] = file.name
          end
        end
        ret = [correct_path, extras]
      end

      def details(path)
        contents(path).first
      end

      def authorized?
        true
      end

    end
  end
end
