module Fluent
# poll spectrum alerts and load as events in to fluentd
  class SpectrumInput < Input
    Fluent::Plugin.register_input('spectrum', self)

    # Define default configurations
    config_param :tag, :string, :default => "alert.spectrum"
    config_param :endpoint, :string, :default => "http://cprdspectws004.corp.intuit.net" # Path /spectrum/restful/alarms
    config_param :interval, :integer, :default => '300'
    config_param :user, :string, :default => "username"
    config_param :pass, :string, :default => "password"
    config_param :include_raw, :string, :default => "false"
    # Add a fields all or list option
    # error checking in every section

    # Initialize and bring in dependencies
    def initialize
      require 'rest_client'
      require 'json'
      super
    end # def initialize

    # Load internal and external configs
    def configure(conf)
      super
      ### Add check for required fields. 
      @conf = conf
      # All attributes we will pull from Spectrum
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
        "0x11f4d" => "ACKNOWLEDGED",
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
      # Setup Rest Call to Spectrum EndPoint
      @url = @endpoint.to_s + '/spectrum/restful/alarms'
      def spectrumEnd
        RestClient::Resource.new(@url,@user,@pass)
      end
    end # def configure

    def start
      super
      @loop = Coolio::Loop.new
      timer_trigger = TimerWatcher.new(@interval, true, &method(:input))
      timer_trigger.attach(@loop)
      @thread = Thread.new(&method(:run))
      $log.info "starting spectrum poller, endpoint #{@endpoint} interval #{@interval}"
    end # def start

    def shutdown
      super
      @loop.stop
      @thread.join
    end

    def run
      @loop.run
    end

    def input
      $log.info "Input loop polling Spectrum - Epoch: #{Engine.now.to_i}"
      # Set current lookback time
      alertStartTime = Engine.now.to_i - @interval.to_i 

      ## XML required for spectrum post
      @xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <rs:alarm-request throttlesize=\"10000\"
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

      def to_utf8(str)
        str = str.force_encoding('UTF-8')
        return str if str.valid_encoding?
        str.encode("UTF-8", 'binary', invalid: :replace, undef: :replace, replace: '')
      end

      responsePost=spectrumEnd.post @xml,:content_type => 'application/xml',:accept => 'application/json'
      body = JSON.parse(responsePost.body)
      body['ns1.alarm-response-list']['ns1.alarm-responses']['ns1.alarm'].each do |alarm|
        record_hash = Hash.new
        record_hash['event_type'] = @tag.to_s
        record_hash['intermediary_source'] = @endpoint.to_s  
        alarm['ns1.attribute'].each do |attribute|
          record_hash[@spectrum_access_code[attribute['@id'].to_s].to_s] = to_utf8(attribute['$'].to_s)
        end
        # include raw?
        if @include_raw.to_s == "true"  
          record_hash['raw'] = alarm  
        end
        Engine.emit(@tag, record_hash['CREATION_DATE'].to_i,record_hash)
      end
    end
  end # class SpectrumInput

  class TimerWatcher < Coolio::TimerWatcher
    def initialize(interval, repeat, &callback)
      @callback = callback
      super(interval, repeat)
    end

    def on_timer
      @callback.call
    end
  end
end # module Fluent