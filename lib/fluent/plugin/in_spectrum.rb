module Fluent
  class SpectrumInput < Input
    Fluent::Plugin.register_input('spectrum', self)
    config_param :tag, :string, :default => "alert.spectrum"
    config_param :endpoint, :string, :default => nil
    config_param :username, :string, :default => nil
    config_param :password, :string, :default => nil
    config_param :interval, :integer, :default => 300 # shoud stay above 10, avg response is 5-7 seconds

    config_param :state_file, :string, :default => nil
    config_param :include_raw, :string, :default => "false"
    config_param :attributes, :string, :default => "ALL"
    config_param :select_limit, :time, :default => 10000

    # Classes
    class TimerWatcher < Coolio::TimerWatcher
      def initialize(interval, repeat, &callback)
        @callback = callback
        super(interval, repeat)
      end # def initialize
      
      def on_timer
        @callback.call
      rescue
        $log.error $!.to_s
        $log.error_backtrace
      end # def on_timer
    end

    class StateStore
      def initialize(path)
        require 'yaml'
        @path = path
        if File.exists?(@path)
          @data = YAML.load_file(@path)
          if @data == false || @data == []
            # this happens if an users created an empty file accidentally
            @data = {}
          elsif !@data.is_a?(Hash)
            raise "state_file on #{@path.inspect} is invalid"
          end
        else
          @data = {}
        end
      end

      def last_records
        @data['last_records'] ||= {}
      end

      def update!
        File.open(@path, 'w') {|f|
          f.write YAML.dump(@data)
        }
      end
    end

    class MemoryStateStore
      def initialize
        @data = {}
      end
      
      def last_records
        @data['last_records'] ||= {}
      end
      
      def update!
      end
    end

    # function to UTF8 encode
    def to_utf8(str)
      str = str.force_encoding('UTF-8')
      return str if str.valid_encoding?
      str.encode("UTF-8", 'binary', invalid: :replace, undef: :replace, replace: '')
    end

    def parseAttributes(alarmAttribute)
      key = @spectrum_access_code[alarmAttribute['@id'].to_s].to_s
      value = ((to_utf8(alarmAttribute['$'].to_s)).strip).gsub(/\r?\n/, " ")
      return key,value
    end

    def initialize
      require 'rest-client'
      require 'json'
      super
    end # def initialize

    def configure(conf)
      super 
      @conf = conf

      unless @state_file
        $log.warn "'state_file PATH' parameter is not set to a valid source."
        $log.warn "this parameter is highly recommended to save the last known good timestamp to resume event consuming"
      end
      # map of Spectrum attribute codes to names
      @spectrum_access_code={
        "0x11f9c" => "ALARM_ID",
        "0x11f4e" => "CREATION_DATE",
        "0x11f56" => "SEVERITY",
        "0x12b4c" => "ALARM_TITLE",
        "0x1006e" => "HOSTNAME",
        "0x12d7f" => "IP_ADDRESS",
        "0x1296e" => "ORIGINATING_EVENT_ATTR",
        "0x10000" => "MODEL_STRING",  
        "0x11f4d" => "ACKNOWLEDGED",
        "0x11f4f" => "ALARM_STATUS",
        "0x11fc5" => "OCCURRENCES",
        "0x11f57" => "TROUBLE_SHOOTER",
        "0x11f9b" => "USER_CLEARABLE",
        "0x12022" => "TROUBLE_TICKET_ID",
        "0x12942" => "PERSISTENT",
        "0x12adb" => "GC_NAME",
        "0x57f0105" => "Custom_Project",
        #{}"0x11f51" => "CLEARED_BY_USER_NAME",
        #{}"0x11f52" => "EVENT_ID_LIST",
        #{}"0x11f53" => "MODEL_HANDLE",
        #{}"0x11f54" => "PRIMARY_ALARM",
        #{}"0x11fc4" => "ALARM_SOURCE",
        #{}"0x11fc6" => "TROUBLE_SHOOTER_MH",
        #{}"0x12a6c" => "TROUBLE_SHOOTER_EMAIL",
        #{}"0x1290d" => "IMPACT_SEVERITY",
        #{}"0x1290e" => "IMPACT_SCOPE",
        #{}"0x1298a" => "IMPACT_TYPE_LIST",
        #{}"0x12948" => "DIAGNOSIS_LOG",
        #{}"0x129aa" => "MODEL_ID",
        #{}"0x129ab" => "MODEL_TYPE_ID",
        #{}"0x129af" => "CLEAR_DATE",
        #{}"0x12a04" => "SYMPTOM_LIST_ATTR",
        #{}"0x12a6f" => "EVENT_SYMPTOM_LIST_ATTR",
        #{}"0x12a05" => "CAUSE_LIST_ATTR",
        #{}"0x12a06" => "SYMPTOM_COUNT_ATTR",
        #{}"0x12a70" => "EVENT_SYMPTOM_COUNT_ATTR",
        #{}"0x12a07" => "CAUSE_COUNT_ATTR",
        #{}"0x12a63" => "WEB_CONTEXT_URL",
        #{}"0x12a6b" => "COMBINED_IMPACT_TYPE_LIST",
        #{}"0x11f50" => "CAUSE_CODE",
        #{}"0x10009" => "SECURITY_STRING"
      }
      # Create XML chunk for attributes we care about
      @attr_of_interest=""
      @spectrum_access_code.each do |key, array|
        @attr_of_interest += " <rs:requested-attribute id=\"#{key}\"/>"
      end
      
      # Setup URL Resource
      def resource
        @url = 'http://' + @endpoint.to_s + '/spectrum/restful/alarms'
        RestClient::Resource.new(@url, :user => @username, :password => @password, :open_timeout => 3, :timeout => (@interval * 2))
      end

      ### need to add this but first figure out how to pass a one time override for timeout since get takes a longtime to return
      #test = resource.get
      #if test.code.to_s == 200
      #  $log.info "Spectrum :: Config testing #{@endpoint} succeeded with #{test.code.to_s} response code"
      #else
      #  raise Fluent::ConfigError, "http test failed"
      #end
    end # def configure

    def start
      @stop_flag = false
      @state_store = @state_file.nil? ? MemoryStateStore.new : StateStore.new(@state_file)
      @loop = Coolio::Loop.new
      @loop.attach(TimerWatcher.new(@interval, true, &method(:on_timer)))
      @thread = Thread.new(&method(:run))
    end # def start

    def shutdown
      #@loop.watchers.each {|w| w.detach}
      @stop_flag = true
      @loop.stop
      @thread.join
    end # def shutdown

    def run
      @loop.run
    rescue
      $log.error "unexpected error", :error=>$!.to_s
      $log.error_backtrace
    end # def run

    def on_timer
      if not @stop_flag
        pollingStart = Engine.now.to_i
        if @state_store.last_records.has_key?("spectrum") 
          alertStartTime = @state_store.last_records['spectrum']
          #$log.info "Spectrum :: Got time record from state_store - #{alertStartTime}" 
        else
          alertStartTime = (pollingStart.to_i - @interval.to_i)
          #$log.info "Spectrum :: Got time record from initial config - #{alertStartTime}"
        end
        pollingEnd = ''
        pollingDuration = ''
        #$log.info "Spectrum :: Polling alerts for time period < #{alertStartTime.to_i}"

        # Format XML for spectrum post
        @xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <rs:alarm-request throttlesize=\"#{select_limit}\"
        xmlns:rs=\"http://www.ca.com/spectrum/restful/schema/request\"
        xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
        xsi:schemaLocation=\"http://www.ca.com/spectrum/restful/schema/request ../../../xsd/Request.xsd \">
        <rs:attribute-filter>
          <search-criteria xmlns=\"http://www.ca.com/spectrum/restful/schema/filter\">
          <filtered-models>
            <greater-than>
              <attribute id=\"0x11f4e\">
                <value> #{alertStartTime} </value>
              </attribute>
            </greater-than>
          </filtered-models>
          </search-criteria>
        </rs:attribute-filter>
        #{@attr_of_interest}
        </rs:alarm-request>"

        # Post to Spectrum and parse results
        begin
          res=resource.post @xml,:content_type => 'application/xml',:accept => 'application/json'
          #$log.info "Response code #{res.code.to_s}"
          body = JSON.parse(res.body)
          pollingEnd = Engine.now.to_i
          @state_store.last_records['spectrum'] = pollingEnd
          pollingDuration = pollingEnd - pollingStart
        end  

        # Processing for multiple alerts returned
        if body['ns1.alarm-response-list']['@total-alarms'].to_i > 1
          $log.info "Spectrum :: returned #{body['ns1.alarm-response-list']['@total-alarms'].to_i} alarms for period < #{alertStartTime.to_i} took #{pollingDuration.to_i} seconds, ended at #{pollingEnd}"
          # iterate through each alarm
          body['ns1.alarm-response-list']['ns1.alarm-responses']['ns1.alarm'].each do |alarm|
            # Create initial structure
            record_hash = Hash.new # temp hash to hold attributes of alarm
            raw_array = Array.new # temp hash to hold attributes of alarm for raw
            record_hash['event_type'] = @tag.to_s
            record_hash['intermediary_source'] = @endpoint.to_s
            record_hash['recieved_time_input'] = pollingEnd.to_s
            # iterate though alarm attributes
            alarm['ns1.attribute'].each do |attribute|
              key,value = parseAttributes(attribute)
              record_hash[key] = value
              if @include_raw.to_s == "true"
                raw_array << { "#{key}" => "#{value}" }
              end
            end
            # append raw object
            if @include_raw.to_s == "true"  
              record_hash[:raw] = raw_array
            end
            Engine.emit(@tag, record_hash['CREATION_DATE'].to_i,record_hash)
          end
        # Processing for single alarm returned  
        elsif body['ns1.alarm-response-list']['@total-alarms'].to_i == 1
          $log.info "Spectrum :: returned #{body['ns1.alarm-response-list']['@total-alarms'].to_i} alarms for period < #{alertStartTime.to_i} took #{pollingDuration.to_i} seconds, ended at #{pollingEnd}"
          # Create initial structure
          record_hash = Hash.new # temp hash to hold attributes of alarm
          raw_array = Array.new # temp hash to hold attributes of alarm for raw
          record_hash['event_type'] = @tag.to_s
          record_hash['intermediary_source'] = @endpoint.to_s
          record_hash['recieved_time_input'] = pollingEnd.to_s
          # iterate though alarm attributes and add to temp hash  
          body['ns1.alarm-response-list']['ns1.alarm-responses']['ns1.alarm']['ns1.attribute'].each do |attribute|
            key,value = parseAttributes(attribute)
            record_hash[key] = value
            if @include_raw.to_s == "true"
              raw_array << { "#{key}" => "#{value}" }
            end
          end
          # append raw object
          if @include_raw.to_s == "true"  
            record_hash[:raw] = raw_array
          end
          Engine.emit(@tag, record_hash['CREATION_DATE'].to_i,record_hash)
        # No alarms returned
        else
          $log.info "Spectrum :: returned #{body['ns1.alarm-response-list']['@total-alarms'].to_i} alarms for period < #{alertStartTime.to_i} took #{pollingDuration.to_i} seconds, ended at #{pollingEnd}"
        end
        @state_store.update!
        #return 
        #exit   
      end
    end # def input
  end # class SpectrumInput
end # module Fluent