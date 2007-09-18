module ActsAsSolr #:nodoc:
  
  #Currently you must have Rails Cron enabled to use this sub-module.
  module BackgroundMethods
    def solr_save_delayed
      begin
        command_string = "#{self.class}.find_by_id(#{self.id}).solr_save_one_time"
        unless cron_job = RailsCron.find_by_command(command_string)
          cron_job = RailsCron.new(:concurrent => true)
        end
        cron_job.command = command_string
        cron_job.start = self.class.configuration[:background].minutes.from_now
        cron_job.every = 1.minute
        cron_job.finish = (self.class.configuration[:background] + 2).minutes.from_now
        cron_job.save
      rescue => e
        raise e + "Is rails_cron installed?"
      end
    end
    
    def solr_save_one_time
      self.solr_save
      command_string = "#{self.class}.find_by_id(#{self.id}).solr_save_one_time"
      if cron_job = RailsCron.find_by_command(command_string)
        cron_job.destroy
      end
    end
  end
  
  
end