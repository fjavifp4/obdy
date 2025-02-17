from datetime import datetime
from bson import ObjectId

class User:
    def __init__(self, username: str, email: str, password_hash: str):
        self._id = ObjectId()
        self.username = username
        self.email = email
        self.hashed_password = password_hash
        self.created_at = datetime.utcnow()
        self.updated_at = self.created_at

    @staticmethod
    async def find_by_email(db, email: str):
        return await db.users.find_one({"email": email})

    @staticmethod
    async def find_by_id(db, user_id: str):
        return await db.users.find_one({"_id": ObjectId(user_id)}) 