from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import sqlite3
import json
import uuid
import time
import random
import threading
from typing import Optional, List

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    conn = sqlite3.connect('game.db', timeout=10)
    conn.row_factory = sqlite3.Row
    conn.text_factory = str
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA encoding = 'UTF-8'")
    return conn

def init_db():
    conn = get_db()
    conn.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            login TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            token TEXT UNIQUE,
            nickname TEXT DEFAULT 'player',
            experience INTEGER DEFAULT 0,
            avatar TEXT DEFAULT NULL,
            friends TEXT DEFAULT '[]',
            requests TEXT DEFAULT '[]',
            achievements TEXT DEFAULT '[]'
        )
    ''')
    conn.execute('''
        CREATE TABLE IF NOT EXISTS game_sessions (
            id TEXT PRIMARY KEY,
            player1_id INTEGER NOT NULL,
            player2_id INTEGER,
            state TEXT DEFAULT 'waiting',
            player1_words9_json TEXT,
            player2_words9_json TEXT,
            player1_selected_json TEXT,
            player2_selected_json TEXT,
            round INTEGER DEFAULT 0,
            max_rounds INTEGER DEFAULT 5,
            player1_answers_json TEXT DEFAULT '[]',
            player2_answers_json TEXT DEFAULT '[]',
            player1_time REAL DEFAULT 0,
            player2_time REAL DEFAULT 0,
            start_time REAL,
            FOREIGN KEY(player1_id) REFERENCES users(id),
            FOREIGN KEY(player2_id) REFERENCES users(id)
        )
    ''')
    conn.execute('''
        CREATE TABLE IF NOT EXISTS invites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_id INTEGER NOT NULL,
            to_id INTEGER NOT NULL,
            session_id TEXT,
            status TEXT DEFAULT 'pending',
            FOREIGN KEY(from_id) REFERENCES users(id),
            FOREIGN KEY(to_id) REFERENCES users(id)
        )
    ''')
    conn.commit()
    conn.close()

init_db()

# Модели
class UserRegister(BaseModel):
    login: str
    password: str

class UserLogin(BaseModel):
    login: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class FriendRequest(BaseModel):
    target_id: int

class SearchQuery(BaseModel):
    query: str

class UpdateProfileRequest(BaseModel):
    nickname: Optional[str] = None
    avatar: Optional[str] = None

class UpdateStatsRequest(BaseModel):
    experience: int
    achievements: str = '[]'

class InviteRequest(BaseModel):
    friend_id: int

class SelectWordsRequest(BaseModel):
    session_id: str
    words: List[str]

class SubmitAnswerRequest(BaseModel):
    session_id: str
    answers: List[str]

def get_current_user(x_auth_token: str = Header(None)):
    if not x_auth_token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    conn = get_db()
    row = conn.execute("SELECT id FROM users WHERE token = ?", (x_auth_token,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid token")
    return row["id"]

def get_random_words(count=9):
    sample = ["cat", "dog", "sun", "book", "water", "house", "tree", "car", "apple", "milk",
              "beautiful", "dangerous", "knowledge", "furniture", "important",
              "ambiguous", "phenomenon", "exaggerate", "conscience", "embarrass"]
    random.shuffle(sample)
    return sample[:count]

# ---------- ОСНОВНЫЕ ЭНДПОИНТЫ (без изменений) ----------
@app.post("/register", response_model=Token)
def register(user: UserRegister):
    conn = get_db()
    try:
        if conn.execute("SELECT id FROM users WHERE login = ?", (user.login,)).fetchone():
            raise HTTPException(status_code=400, detail="Login already taken")
        token = str(uuid.uuid4())
        conn.execute("INSERT INTO users (login, password, token) VALUES (?, ?, ?)", (user.login, user.password, token))
        conn.commit()
        return {"access_token": token, "token_type": "bearer"}
    finally:
        conn.close()

@app.post("/login", response_model=Token)
def login(user: UserLogin):
    conn = get_db()
    try:
        row = conn.execute("SELECT id, password, token FROM users WHERE login = ?", (user.login,)).fetchone()
        if not row or row["password"] != user.password:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        return {"access_token": row["token"], "token_type": "bearer"}
    finally:
        conn.close()

@app.get("/profile")
def get_profile(user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="User not found")
        level = 1 + row["experience"] // 100
        friends_ids = json.loads(row["friends"])
        requests_ids = json.loads(row["requests"])
        friends_data, requests_data = [], []
        if friends_ids or requests_ids:
            conn2 = get_db()
            try:
                for fid in friends_ids:
                    fr = conn2.execute("SELECT id, nickname, experience, avatar FROM users WHERE id = ?", (fid,)).fetchone()
                    if fr:
                        friends_data.append({"id": fr["id"], "nickname": fr["nickname"], "level": 1 + fr["experience"] // 100, "avatar": fr["avatar"]})
                for rid in requests_ids:
                    rr = conn2.execute("SELECT id, nickname, experience, avatar FROM users WHERE id = ?", (rid,)).fetchone()
                    if rr:
                        requests_data.append({"id": rr["id"], "nickname": rr["nickname"], "level": 1 + rr["experience"] // 100, "avatar": rr["avatar"]})
            finally:
                conn2.close()
        return {
            "id": row["id"], "nickname": row["nickname"], "level": level, "experience": row["experience"],
            "avatar": row["avatar"], "friends": friends_data, "requests": requests_data,
            "achievements": json.loads(row["achievements"])
        }
    finally:
        conn.close()

@app.put("/profile")
def update_profile(data: UpdateProfileRequest, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        if data.nickname is not None:
            conn.execute("UPDATE users SET nickname = ? WHERE id = ?", (data.nickname, user_id))
        if data.avatar is not None:
            conn.execute("UPDATE users SET avatar = ? WHERE id = ?", (data.avatar, user_id))
        conn.commit()
        return {"status": "ok"}
    finally:
        conn.close()

@app.post("/friend_request")
def friend_request(req: FriendRequest, user_id: int = Depends(get_current_user)):
    if req.target_id == user_id:
        raise HTTPException(status_code=400, detail="Cannot send request to yourself")
    conn = get_db()
    try:
        target = conn.execute("SELECT requests, friends FROM users WHERE id = ?", (req.target_id,)).fetchone()
        if not target:
            raise HTTPException(status_code=404, detail="User not found")
        target_requests = json.loads(target["requests"])
        target_friends = json.loads(target["friends"])
        if user_id in target_friends:
            raise HTTPException(status_code=400, detail="Already friends")
        if user_id in target_requests:
            raise HTTPException(status_code=400, detail="Request already sent")
        target_requests.append(user_id)
        conn.execute("UPDATE users SET requests = ? WHERE id = ?", (json.dumps(target_requests), req.target_id))
        conn.commit()
        return {"status": "ok"}
    finally:
        conn.close()

@app.post("/accept_request")
def accept_request(req: FriendRequest, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        user = conn.execute("SELECT requests, friends FROM users WHERE id = ?", (user_id,)).fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        user_requests = json.loads(user["requests"])
        if req.target_id not in user_requests:
            raise HTTPException(status_code=400, detail="No such request")
        user_requests.remove(req.target_id)
        user_friends = json.loads(user["friends"])
        user_friends.append(req.target_id)
        conn.execute("UPDATE users SET requests = ?, friends = ? WHERE id = ?", (json.dumps(user_requests), json.dumps(user_friends), user_id))
        other = conn.execute("SELECT friends FROM users WHERE id = ?", (req.target_id,)).fetchone()
        other_friends = json.loads(other["friends"])
        other_friends.append(user_id)
        conn.execute("UPDATE users SET friends = ? WHERE id = ?", (json.dumps(other_friends), req.target_id))
        conn.commit()
        return {"status": "ok"}
    finally:
        conn.close()

@app.post("/decline_request")
def decline_request(req: FriendRequest, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        user_requests = json.loads(conn.execute("SELECT requests FROM users WHERE id = ?", (user_id,)).fetchone()["requests"])
        if req.target_id not in user_requests:
            raise HTTPException(status_code=400, detail="No such request")
        user_requests.remove(req.target_id)
        conn.execute("UPDATE users SET requests = ? WHERE id = ?", (json.dumps(user_requests), user_id))
        conn.commit()
        return {"status": "ok"}
    finally:
        conn.close()

@app.post("/search_users")
def search_users(query: SearchQuery, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        try:
            target_id = int(query.query)
            row = conn.execute("SELECT id, nickname, experience, avatar FROM users WHERE id = ?", (target_id,)).fetchone()
            if not row:
                return []
            level = 1 + row["experience"] // 100
            return [{"id": row["id"], "nickname": row["nickname"], "level": level, "avatar": row["avatar"]}]
        except ValueError:
            rows = conn.execute("SELECT id, nickname, experience, avatar FROM users WHERE nickname LIKE ?", (f"%{query.query}%",)).fetchall()
            result = []
            for r in rows:
                level = 1 + r["experience"] // 100
                result.append({"id": r["id"], "nickname": r["nickname"], "level": level, "avatar": r["avatar"]})
            return result
    finally:
        conn.close()

@app.post("/update_stats")
def update_stats(data: UpdateStatsRequest, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        conn.execute("UPDATE users SET experience = ?, achievements = ? WHERE id = ?", (data.experience, data.achievements, user_id))
        conn.commit()
        return {"status": "ok"}
    finally:
        conn.close()

# ---------- PvP ----------
@app.post("/invite")
def invite(inv: InviteRequest, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        friends = json.loads(conn.execute("SELECT friends FROM users WHERE id = ?", (user_id,)).fetchone()["friends"])
        if inv.friend_id not in friends:
            raise HTTPException(status_code=400, detail="Not friends")
        session_id = str(uuid.uuid4())
        conn.execute("INSERT INTO game_sessions (id, player1_id, state) VALUES (?, ?, 'waiting')", (session_id, user_id))
        conn.execute("INSERT INTO invites (from_id, to_id, session_id) VALUES (?, ?, ?)", (user_id, inv.friend_id, session_id))
        conn.commit()
        return {"session_id": session_id}
    finally:
        conn.close()

@app.get("/poll_invites")
def poll_invites(user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        invites = conn.execute(
            "SELECT i.id, i.from_id, u.nickname, u.avatar, u.experience, i.session_id FROM invites i JOIN users u ON i.from_id = u.id WHERE i.to_id = ? AND i.status = 'pending'",
            (user_id,)
        ).fetchall()
        result = []
        for inv in invites:
            level = 1 + inv["experience"] // 100
            result.append({"invite_id": inv["id"], "from_id": inv["from_id"], "nickname": inv["nickname"], "avatar": inv["avatar"], "level": level, "session_id": inv["session_id"]})
        return result
    finally:
        conn.close()

@app.post("/accept_invite")
def accept_invite(invite_id: int, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        inv = conn.execute("SELECT * FROM invites WHERE id = ? AND to_id = ? AND status = 'pending'", (invite_id, user_id)).fetchone()
        if not inv:
            raise HTTPException(status_code=404, detail="Invite not found")
        conn.execute("UPDATE invites SET status = 'accepted' WHERE id = ?", (invite_id,))
        words1, words2 = get_random_words(9), get_random_words(9)
        conn.execute("UPDATE game_sessions SET player2_id = ?, state = 'accepted', player1_words9_json = ?, player2_words9_json = ? WHERE id = ?",
                     (user_id, json.dumps(words1), json.dumps(words2), inv["session_id"]))
        conn.commit()
        # Через 4 секунды переведём в words_select
        def switch_to_words_select():
            time.sleep(4)
            conn2 = get_db()
            try:
                session = conn2.execute("SELECT state FROM game_sessions WHERE id = ?", (inv["session_id"],)).fetchone()
                if session and session["state"] == "accepted":
                    conn2.execute("UPDATE game_sessions SET state = 'words_select' WHERE id = ?", (inv["session_id"],))
                    conn2.commit()
            finally:
                conn2.close()
        threading.Thread(target=switch_to_words_select, daemon=True).start()
        return {"status": "ok"}
    finally:
        conn.close()

@app.post("/decline_invite")
def decline_invite(invite_id: int, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        conn.execute("UPDATE invites SET status = 'declined' WHERE id = ? AND to_id = ?", (invite_id, user_id))
        conn.commit()
        return {"status": "ok"}
    finally:
        conn.close()

@app.get("/get_game_state")
def get_game_state(session_id: str, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        session = conn.execute("SELECT * FROM game_sessions WHERE id = ?", (session_id,)).fetchone()
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        player_key = "1" if session["player1_id"] == user_id else "2"
        opponent_id = session["player2_id"] if player_key == "1" else session["player1_id"]
        opponent = None
        if opponent_id is not None:
            opponent = conn.execute("SELECT nickname, avatar, experience FROM users WHERE id = ?", (opponent_id,)).fetchone()
        words9 = json.loads(session[f"player{player_key}_words9_json"] or "[]")
        selected = json.loads(session[f"player{player_key}_selected_json"] or "[]")
        opponent_selected = json.loads(session[f"player{1 if player_key == '2' else 2}_selected_json"] or "[]")
        player_answers = json.loads(session[f"player{player_key}_answers_json"] or "[]")
        opponent_answers = json.loads(session[f"player{1 if player_key == '2' else 2}_answers_json"] or "[]")
        result = {
            "state": session["state"],
            "round": session["round"],
            "max_rounds": session["max_rounds"],
            "words9": words9,
            "selected": selected,
            "opponent_selected": opponent_selected,
            "player_key": player_key,
            "player_answers": player_answers,
            "opponent_answers": opponent_answers,
            "player_time": session[f"player{player_key}_time"],
            "opponent_time": session[f"player{1 if player_key == '2' else 2}_time"],
        }
        if opponent:
            result.update({
                "opponent_nickname": opponent["nickname"],
                "opponent_avatar": opponent["avatar"],
                "opponent_level": 1 + opponent["experience"] // 100,
            })
        else:
            result.update({
                "opponent_nickname": "Ожидание...",
                "opponent_avatar": None,
                "opponent_level": 0,
            })
        return result
    finally:
        conn.close()

@app.post("/select_words")
def select_words(req: SelectWordsRequest, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        session = conn.execute("SELECT * FROM game_sessions WHERE id = ?", (req.session_id,)).fetchone()
        if not session or session["state"] != "words_select":
            raise HTTPException(status_code=400, detail="Invalid state")
        if len(req.words) != 3:
            raise HTTPException(status_code=400, detail="Must select exactly 3 words")
        player_key = "1" if session["player1_id"] == user_id else "2"
        conn.execute(f"UPDATE game_sessions SET player{player_key}_selected_json = ? WHERE id = ?", (json.dumps(req.words), req.session_id))
        other_key = "2" if player_key == "1" else "1"
        if session[f"player{other_key}_selected_json"]:
            conn.execute("UPDATE game_sessions SET state = 'playing', start_time = ? WHERE id = ?", (time.time(), req.session_id))
        conn.commit()
        return {"status": "ok"}
    finally:
        conn.close()

@app.post("/submit_answer")
def submit_answer(req: SubmitAnswerRequest, user_id: int = Depends(get_current_user)):
    conn = get_db()
    try:
        session = conn.execute("SELECT * FROM game_sessions WHERE id = ?", (req.session_id,)).fetchone()
        if not session or session["state"] != "playing":
            raise HTTPException(status_code=400, detail="Invalid state")
        if len(req.answers) != 3:
            raise HTTPException(status_code=400, detail="Must provide exactly 3 answers")
        player_key = "1" if session["player1_id"] == user_id else "2"
        other_key = "2" if player_key == "1" else "1"
        elapsed = time.time() - session["start_time"]
        current_time = session[f"player{player_key}_time"] + elapsed
        player_answers = json.loads(session[f"player{player_key}_answers_json"] or "[]")
        player_answers.append(req.answers)
        conn.execute(f"UPDATE game_sessions SET player{player_key}_answers_json = ?, player{player_key}_time = ?, start_time = ? WHERE id = ?",
                     (json.dumps(player_answers), current_time, time.time(), req.session_id))
        other_answers = json.loads(session[f"player{other_key}_answers_json"] or "[]")
        current_round = session["round"]
        if len(player_answers) > current_round and len(other_answers) > current_round:
            if current_round + 1 >= session["max_rounds"]:
                conn.execute("UPDATE game_sessions SET state = 'finished', round = ? WHERE id = ?", (current_round + 1, req.session_id))
            else:
                words1, words2 = get_random_words(9), get_random_words(9)
                conn.execute("UPDATE game_sessions SET state = 'words_select', round = ?, player1_words9_json = ?, player2_words9_json = ?, player1_selected_json = NULL, player2_selected_json = NULL WHERE id = ?",
                             (current_round + 1, json.dumps(words1), json.dumps(words2), req.session_id))
        conn.commit()
        return {"status": "ok"}
    finally:
        conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)