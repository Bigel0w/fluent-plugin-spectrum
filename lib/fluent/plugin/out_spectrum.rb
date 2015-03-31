module Fluent
  class SpectrumOut < Output
    # First, register the plugin. NAME is the name of this plugin
    # and identifies the plugin in the configuration file.
    Fluent::Plugin.register_output('spectrum', self)
    
    config_param :tag, :string, default:'alert.spectrum.out' 
    #config_param :tag, :string, :default => "alert.spectrum"
    config_param :endpoint, :string, :default => "pleasechangeme.com" #fqdn of endpoint
    config_param :interval, :integer, :default => '300' #Default 5 minutes
    config_param :user, :string, :default => "username"
    config_param :pass, :string, :default => "password"
    config_param :include_raw, :string, :default => "false" #Include original object as raw
    config_param :attributes, :string, :default => "ALL" # fields to include, ALL for... well, ALL.

    def parseAttributes(alarmAttribute)
      key = @spectrum_access_code[alarmAttribute['@id'].to_s].to_s
      value = ((to_utf8(alarmAttribute['$'].to_s)).strip).gsub(/\r?\n/, " ")
      return key,value
    end

    def initialize
      require 'rest-client'
      require 'json'
      require 'pp'
      require 'cgi'
      super
    end # def initialize


    # This method is called before starting.
    def configure(conf)
      super 
      # Read property file and create a hash
      @rename_rules = []
      conf_rename_rules = conf.keys.select { |k| k =~ /^rename_rule(\d+)$/ }
      conf_rename_rules.sort_by { |r| r.sub('rename_rule', '').to_i }.each do |r|
        key_regexp, new_key = parse_rename_rule conf[r]

        if key_regexp.nil? || new_key.nil?
          raise Fluent::ConfigError, "Failed to parse: #{r} #{conf[r]}"
        end

        if @rename_rules.map { |r| r[:key_regexp] }.include? /#{key_regexp}/
          raise Fluent::ConfigError, "Duplicated rules for key #{key_regexp}: #{@rename_rules}"
        end

        #@rename_rules << { key_regexp: /#{key_regexp}/, new_key: new_key }
        @rename_rules << { key_regexp: key_regexp, new_key: new_key }
        $log.info "Added rename key rule: #{r} #{@rename_rules.last}"
      end

      raise Fluent::ConfigError, "No rename rules are given" if @rename_rules.empty?
      @conf = conf
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
        "0x11f4d" => "ACKNOWLEDGED",
        "0xffff00ed" => "application_name",
        "0xffff00f1" => "business_unit_l1",
        "0xffff00f2" => "business_unit_l2",
        "0xffff00f3" => "business_unit_l3",
        "0xffff00f4" => "business_unit_l4",
        "0xffff00f0" => "cmdb_ci_sysid",

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
      	@url = 'http://' + @endpoint.to_s + '/spectrum/restful/alarms/'
   end

  def parse_rename_rule rule
    if rule.match /^([^\s]+)\s+(.+)$/
      return $~.captures
    end
  end

    # This method is called when starting.
    def start
      super
    end

    # This method is called when shutting down.
    def shutdown
      super
    end

    # This method is called when an event reaches Fluentd.
    # 'es' is a Fluent::EventStream object that includes multiple events.
    # You can use 'es.each {|time,record["event"]| ... }' to retrieve events.
    # 'chain' is an object that manages transactions. Call 'chain.next' at
    # appropriate points and rollback if it raises an exception.
    #
    # NOTE! This method is called by Fluentd's main thread so you should not write slow routine here. It causes Fluentd's performance degression.
    def emit(tag, es, chain)
      chain.next
      es.each {|time,record|
        $stderr.puts "OK!"
	## Check if the incoming event already has an event id (alarm id) and a corresponding tag of spectrum 
	if (record["event"].has_key?("source_event_id") && record["event"].has_key?("event_type"))  
		# If the value on event_type is spectrum, then it means that ti is already from spectrum and needs an update		
		if (record["event"].has_value?("alert.spectrum"))

			# Create an empty hash
			alertUpdateHash=Hash.new

			# Parse thro the array hash that contains name value pairs for hash mapping and add new records to a new hash
			@rename_rules.each { |rule| 
				pp rule[:new_key]
				alertUpdateHash[rule[:key_regexp]]=record["event"][rule[:new_key]]
			}
			# construct the url and iterate to construct the uri
			@urlrest = @url + record["event"]["source_event_id"]
       			alertUpdateHash.each do |attr, val| 
				if (val.nil? || val.empty?)
					next
				else
					if (@urlrest =~ /#{record["event"]["source_event_id"]}\s*$/)
						@urlrest = @urlrest + "?attr=" + attr + "&val=" + CGI.escape(val.to_s)
					else
						@urlrest = @urlrest + "&attr=" + attr + "&val=" + CGI.escape(val.to_s)
					end
				end
			end	
			
			$log.info "Rest url " + @urlrest
       			#RestClient::Resource.new(@user,@pass)
			begin		
				responsePostAffEnt=RestClient::Resource.new(@urlrest,@user,@pass).put(@urlrest,:content_type => 'application/json')
			rescue Exception => e 
				$log.error "Error in restful put call."
				log.error e.backtrace.inspect
				$log.error responsePostAffEnt
			end
		
		else

			# For now just throw to stdout
			$log.info record["event"]

		end		

	end
      }
    end
  end
end