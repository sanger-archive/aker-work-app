Rails.application.config.after_initialize do

  # So you don't have to be connected to SS to view DataReleaseStrategy stuff
  if !Rails.application.config.data_release_client[:enabled]
    module DataReleaseStrategyClient

      # Returns the data release strategy by uuid.
      def self.find_strategy_by_uuid(uuid)
        DataReleaseStrategy.find(uuid)
      end

      # Returns all the DataReleaseStrategy models
      # Creates some if there aren't any
      def self.find_strategies_by_user(user)
        FactoryBot.create_list(:data_release_strategy, 3) if !DataReleaseStrategy.any?
        return DataReleaseStrategy.all
      end

    end
  end

end