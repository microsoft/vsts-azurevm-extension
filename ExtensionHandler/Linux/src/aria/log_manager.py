from aria.log_manager_impl import LogManagerImpl

class LogManager(object):
    """!
    @brief Log Manager static class manages the telemetry logging system
    """
    __implementation = LogManagerImpl

    @staticmethod
    def initialize(tenantToken, log_manager_conf = None):
        """!
        @brief Initializes the telemetry logging system with the specified tenant token and custom cofiguration.

        @param tenantToken Default tenant token that will be used when GetLogger() is called (\b str)
        @param log_manager_conf Configuration that will be used for the duration of the process (\b LogManagerConfiguration)
        @return  The logger that has the tenantToken menetioned 
        @see @ref aria.configuration.LogManagerConfiguration "LogManagerConfiguration"
        """
        return LogManager._LogManager__implementation.initialize(tenantToken, log_manager_conf)

    @staticmethod
    def add_subscriber(subscriber):
        """!
        @brief Adding a subscriber to the sdk events list
        @param subscriber: Metod that has 3 parameters, the tenant token string, a list of events ID and the result for all the events
        """
        LogManager._LogManager__implementation.add_subscriber(subscriber)
    
    @staticmethod
    def remove_subscriber(subscriber):
        """!
        @brief Removes one of the subscriber
        @param subscriber The subscriber that is wanted to be removed
        """
        LogManager._LogManager__implementation.remove_subscriber(subscriber)
        
    @staticmethod
    def remove_all_subscriber():
        """!
        @brief Remove all subscribers
        """
        LogManager._LogManager__implementation.remove_all_subscriber()
    
    @staticmethod    
    def get_logger(source="", tenantToken=""):
        """!
        @brief Returns the logger that has the source and the tenantToken mention, if it doesn't exist, it will create a new one
        @param source Source for your tenat, it can also be empty (\b str)
        @param tenantToken TenantToken to map your logger to a specified token (\b str)
        @return  The logger that has the source and the tenantToken mention, if it doesn't exist, it will create a new one
        @see @ref aria.logger.Logger "Logger"
        """
        return LogManager._LogManager__implementation.get_logger(source, tenantToken)
            
    @staticmethod
    def flush(timeout = 10):
        """!
        @brief flush all the events in memory in the amount of time specified
        @param timeout Time limit for the flush to end (\b int)
        """
        LogManager._LogManager__implementation.flush(timeout)

    @staticmethod
    def flush_and_tead_down():
        """!
        @brief It is called at the end to ensure all threads are stopped and all data is delated
        """
        LogManager._LogManager__implementation.flush_and_tead_down