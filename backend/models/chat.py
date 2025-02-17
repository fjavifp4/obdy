from datetime import datetime
from bson import ObjectId
from typing import List, Optional

class Message:
    def __init__(self, role: str, content: str):
        self.role = role
        self.content = content
        self.timestamp = datetime.utcnow()

class Chat:
    def __init__(
        self,
        user_id: ObjectId,
        vehicle_id: Optional[ObjectId] = None,
        messages: List[Message] = None
    ):
        self._id = ObjectId()
        self.user_id = user_id
        self.vehicle_id = vehicle_id
        self.messages = messages or []
        self.created_at = datetime.utcnow()
        self.updated_at = self.created_at 