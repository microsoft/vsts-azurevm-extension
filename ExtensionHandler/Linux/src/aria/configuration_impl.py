from __future__ import absolute_import
from .log_config import LogConfiguration
from .configuration_limits import ConfiguationLimits
import multiprocessing

class LogManagerConfigurationImpl(object):
    def __init__(self, tcp_connections
                     , max_events_to_batch
                     , max_events_in_memory
                     , log_configuration
                     , drop_event_if_max_is_reached
                     , batching_threads_count
                     , all_threads_daemon):
        if log_configuration == None:
            log_configuration = LogConfiguration()

        # Prechecks:
        if tcp_connections > ConfiguationLimits.MAX_TCP_CONNECTION_ALLOWED or tcp_connections < ConfiguationLimits.MIN_TCP_CONNECTION_ALLOWED:
            raise Exception("TCP Connection can't be higher than " + str(ConfiguationLimits.MAX_TCP_CONNECTION_ALLOWED) +
                            " or lower than " + str(ConfiguationLimits.MIN_TCP_CONNECTION_ALLOWED))
        
        self.DROP_EVENT_IF_MAX_IS_REACHED = drop_event_if_max_is_reached
        self.log_configuration = log_configuration
        self.MAX_EVENTS_IN_MEMORY = max_events_in_memory
        self.BATCHER_TIMER = 0.050                          # ms
        self.SENDER_TIMER = 0.100                           # ms
        self.SENDER_LAZY_TIMER = 10                         # Seconds
        self.LAZY_BATCHER_TIMER = 10                        # Seconds
        self.MAX_EVENTS_TO_BATCH = max_events_to_batch
        self.TCP_CONNECTIONS = tcp_connections
        self.ARIA_SENDER_TIMER = 0.050
        self.SUPPORT_GZIP = True
        self.MAX_SIZE_ALLOWED = 3 * 1024 * 1024 - 5 * 1024   # 5KB Safe margin
        self.QUEUE_DROPPED_EVENTS = int(min(max_events_to_batch/10, 200))
        self.MAX_RETRY_COUNT = 4
        self.STATS_CADENCE = 3 * 60                                     # 5 minutes between stats
        self.PROCESS_NUMBER = batching_threads_count                      # If this is set up to 0 then BATCHING_THREADS will be used to set up the threads
        self.ALL_THREADS_DEAMON = all_threads_daemon