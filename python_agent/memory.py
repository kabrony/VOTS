"""
memory.py - A simple class to store conversation history in memory,
and possibly retrieve context for advanced LLM queries.
"""
from typing import List, Dict

class ConversationMemory:
    def __init__(self):
        self.messages = []  # holds a list of dictionaries, e.g. [{'role': 'user', 'content': 'Hi!'}, ...]

    def add_message(self, role: str, content: str):
        self.messages.append({"role": role, "content": content})

    def get_history(self, max_tokens:int=2048):
        """
        Return the conversation messages in a format or token-limit manner.
        Example: might truncate or do a fancy summarization if the list is too long.
        """
        # Here we just do a naive approach:
        return self.messages[-10:]  # last 10 messages, for example.

    def clear(self):
        self.messages = []
