from .configuration_impl import LogManagerConfigurationImpl
import multiprocessing

class LogManagerConfiguration(object):
    def __init__(self, tcp_connections = 3
                     , max_events_to_batch = 200
                     , max_events_in_memory = 40000
                     , log_configuration = None
                     , drop_event_if_max_is_reached = True
                     , batching_threads_count = multiprocessing.cpu_count()
                     , all_threads_daemon = False):
        """!@brief Creates a new LogManagerConfiguration object.

            This LogManagerConfiguration is being used to configurate LogManager

            @param tcp_connections Number of TCP connections we create, there will be a thread per TCP connection
            @param max_events_in_memory Maximum number of events in memory at any point.
            @param max_events_to_batch Maximum number of events that are batched together.
            @param log_configuration LogConfiguration for Debugging purposes
            @param drop_event_if_max_is_reached If this is True, old events are dropped to make space for the the new event. If it's false, the latest event is dropped.
            @param batching_threads_count Number of batching threads.
            @param all_threads_daemon Set up all the threads that are created as Daemon or not.
        """
        self.__implementation = LogManagerConfigurationImpl(tcp_connections, 
                                                            max_events_to_batch,
                                                            max_events_in_memory,
                                                            log_configuration,
                                                            drop_event_if_max_is_reached,
                                                            batching_threads_count,
                                                            all_threads_daemon)
       