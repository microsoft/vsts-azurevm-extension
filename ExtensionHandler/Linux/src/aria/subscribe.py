from __future__ import absolute_import
from abc import abstractmethod
from .stats_manager import StatsConstants

class Subscribe(object):
    def __init__(self):
        self.__subscribers = []
        
    def register(self, observer):
        self.__subscribers.append(observer)
        return True
    
    def unregister(self, observer):
        self.__subscribers.remove(observer)
        return True
        
    def unregister_all(self):
        if self.__subscribers:
            del self.__subscribers[:]
        return True
            
    def update(self, tenant, sequence_list, result):
        for subscriber in self.__subscribers:
            if tenant != StatsConstants.stats_tenant_token:
                try:
                    subscriber(tenant, sequence_list, result)
                except:
                    pass    #We don't care if your method failed
        return True

class SubscribeStatus(object):
    PATCHING_FAILED = -1
    NO_INTERNET_CONNECTION = -2
    EVENT_TO_BIG = -3
    BOND_FAILED = -4
    MAX_SIZE_REACHED = -5