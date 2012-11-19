#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

module Resources

  module Pulp

    class Proxy
      def self.post path, body
        Rails.logger.debug "Sending POST request to Pulp: #{path}"
        client = PulpResource.rest_client(Net::HTTP::Post, :post, path_with_pulp_prefix(path))
        client.post body, PulpResource.default_headers
      end

      def self.delete path
        Rails.logger.debug "Sending DELETE request to Pulp: #{path}"
        client = PulpResource.rest_client(Net::HTTP::Delete, :delete, path_with_pulp_prefix(path))
        client.delete(PulpResource.default_headers)
      end

      def self.get path
        Rails.logger.debug "Sending GET request to Pulp: #{path}"
        client = PulpResource.rest_client(Net::HTTP::Get, :get, path_with_pulp_prefix(path))
        client.get(PulpResource.default_headers)
      end

      def self.path_with_pulp_prefix path
        PulpResource.prefix + path
      end
    end

    class PulpResource < HttpResource
      if AppConfig.pulp
        cfg = AppConfig.pulp
        url = cfg.url
        self.prefix = URI.parse(url).path
        self.site = url.gsub(self.prefix, "")
        self.consumer_secret = cfg.oauth_secret
        self.consumer_key = cfg.oauth_key
        self.ca_cert_file = cfg.ca_cert_file
      end


      def self.default_headers
        {'accept' => 'application/json',
         'accept-language' => I18n.locale,
         'content-type' => 'application/json; charset=utf-8'}.merge(::User.pulp_oauth_header)
      end

      # some old Pulp API need text/plain content type
      def self.default_headers_text
        h = self.default_headers
        h['content-type'] = 'text/plain'
        h
      end

      # the path is expected to have trailing slash
      def self.path_with_prefix path
        PulpResource.prefix + path
      end
    end


    class Repository < PulpResource
      class << self
        def start_discovery url, type
          response = post("/pulp/api/services/discovery/repo/", JSON.generate(:url => url, :type => type), self.default_headers)
          return JSON.parse(response.body).with_indifferent_access if response.code == 202
          Rails.logger.error("Failed to start repository discovery. HTTP status: #{response.code}. #{response.body}")
          raise RuntimeError, "#{response.code}, failed to start repository discovery: #{response.body}"
        end
      end
    end

    class Consumer < PulpResource

      class << self

        def errata consumer_id
          response = get(consumer_path(consumer_id) + "errata/", self.default_headers)
          JSON.parse(response.body)
        end

        def errata_by_consumer repos
          repoids_param = nil
          repos.each do |repo|
            if repoids_param.nil?
              repoids_param = "?repoids=" + repo.pulp_id
            else
              repoids_param += "&repoids=" + repo.pulp_id
            end
          end

          url = consumer_path() + "applicable_errata_in_repos/" + repoids_param
          response = get(url, self.default_headers)
          JSON.parse(response.body)
        end

        def consumer_path id = nil
          id.nil? ? "/pulp/api/consumers/" : "/pulp/api/consumers/#{id}/"
        end
      end
    end


  class ConsumerGroup < PulpResource
    class << self
      def install_packages id, package_names, scheduled_time=nil
        url = path(id) + "installpackages/"
        attrs = {:packagenames => package_names}
        attrs[:scheduled_time] = scheduled_time if scheduled_time
        response = self.post(url, attrs.to_json, self.default_headers)
        JSON.parse(response.body).with_indifferent_access
      end

      def uninstall_packages id, package_names, scheduled_time=nil
        url = path(id) + "uninstallpackages/"
        attrs = {:packagenames => package_names}
        attrs[:scheduled_time] = scheduled_time if scheduled_time
        response = self.post(url, attrs.to_json, self.default_headers)
        JSON.parse(response.body).with_indifferent_access
      end

      def update_packages id, package_names, scheduled_time=nil
        url = path(id) + "updatepackages/"
        attrs = {:packagenames => package_names}
        attrs[:scheduled_time] = scheduled_time if scheduled_time
        response = self.post(url, attrs.to_json, self.default_headers)
        JSON.parse(response.body).with_indifferent_access
      end

      def install_package_groups id, package_groups, scheduled_time=nil
        url = path(id) + "installpackagegroups/"
        attrs = {:grpids => package_groups}
        attrs[:scheduled_time] = scheduled_time if scheduled_time
        response = self.post(url, attrs.to_json, self.default_headers)
        JSON.parse(response.body).with_indifferent_access
      end

      def uninstall_package_groups id, package_groups, scheduled_time=nil
        url = path(id) + "uninstallpackagegroups/"
        attrs = {:grpids => package_groups}
        attrs[:scheduled_time] = scheduled_time if scheduled_time
        response = self.post(url, attrs.to_json, self.default_headers)
        JSON.parse(response.body).with_indifferent_access
      end

      def install_errata id, errata_ids, scheduled_time=nil
        url = path(id) + "installerrata/"
        attrs = { :errataids => errata_ids }
        attrs[:scheduled_time] = scheduled_time if scheduled_time
        response = self.post(url, attrs.to_json, self.default_headers)
        JSON.parse(response.body).with_indifferent_access
      end

      def path(id=nil)
        groups = self.path_with_prefix("/consumergroups/")
        id.nil? ? groups : groups + "#{id}/"
      end
    end
  end

  end
end
