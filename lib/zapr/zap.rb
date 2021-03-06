require 'owasp_zap'
require 'terminal-table'

require 'timeout'

include OwaspZap

module Zapr

  class Proxy

    def initialize(target, zap_path, timeout)
      @proxy = Zap.new(:target => target, :zap => zap_path)
      @timeout = timeout
    end

    def start
      Timeout.timeout(@timeout) do
        @proxy.start(:daemon => true)
        sleep(1) until @proxy.running?
      end
    end


    def spider
      Timeout.timeout(@timeout) do
        @proxy.spider.start
        sleep(1) until (JSON.parse(@proxy.status_for(:spider))['status'] == '100')
      end
    end

    def attack
      Timeout.timeout(@timeout) do
        @proxy.ascan.start
        sleep(1) until (JSON.parse(@proxy.status_for(:ascan))['status'] == '100')
      end
    end

    def shutdown
      @proxy.shutdown
    end

    def pretty_alerts
      JSON.pretty_generate(alerts)
    end

    def alerts
      alerts = JSON.parse(@proxy.alerts.view)['alerts']
      alerts.sort_by! { |item| item["risk"] }
    end

    def exit_code
      high = 0
      alerts.each do |alert|
        high += 1 if alert['risk'] == 'High'
      end
      return high
    end

    def summary
      sorted = alerts.group_by { |item| item["alert"] }
      Terminal::Table.new :headings => ['Alert', 'Risk', 'URL'] do |t|
        sorted.each_with_index do |(alert_name, grouped_alerts), index|
          urls = []
          grouped_alerts.each do |alert|
            urls << alert['url']
          end
          t.add_separator unless index == 0
          t.add_row [alert_name, grouped_alerts[0]['risk'], urls.join("\n")]
        end
      end
    end

  end

end
