from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from enum import Enum

class MessageRole(str, Enum):
    user = "user"
    assistant = "assistant"

class MessageBase(BaseModel):
    content: str

class MessageCreate(MessageBase):
    pass

class MessageResponse(MessageBase):
    id: str
    isFromUser: bool
    timestamp: datetime

class ChatBase(BaseModel):
    vehicleId: Optional[str] = None
    initialMessage: Optional[str] = None

class ChatCreate(ChatBase):
    pass

class ChatResponse(BaseModel):
    id: str
    userId: str
    vehicleId: Optional[str] = None
    messages: List[MessageResponse] = []
    createdAt: datetime
    updatedAt: datetime

    class Config:
        from_attributes = True
        populate_by_name = True

class Message(BaseModel):
    role: MessageRole
    content: str = Field(..., min_length=1)
    timestamp: datetime = Field(default_factory=datetime.utcnow) 