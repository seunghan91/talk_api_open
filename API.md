# Talk API 문서

## 인증 API

### 인증 코드 요청

**URL**: `/api/auth/request_code`
**Method**: `POST`
**Parameters**:
```json
{
  "phone_number": "01012345678"
}


인증 코드 확인
URL: /api/auth/verify_code
Method: POST
Parameters:
jsonCopy{
  "phone_number": "01012345678",
  "code": "123456"
}
응답 예시:
jsonCopy{
  "message": "인증 완료",
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "phone_number": "01012345678",
    "verified": true,
    "gender": "male"
  }
}
브로드캐스트 API
브로드캐스트 목록 조회
URL: /api/broadcasts
Method: GET
Header: Authorization: Bearer {token}
응답 예시:
jsonCopy[
  {
    "id": 1,
    "user_id": 1,
    "active": true,
    "expired_at": "2023-03-01T12:00:00Z",
    "created_at": "2023-02-23T12:00:00Z",
    "updated_at": "2023-02-23T12:00:00Z",
    "user": {
      "id": 1,
      "nickname": "User1",
      "gender": "male"
    }
  }
]
브로드캐스트 생성
URL: /api/broadcasts
Method: POST
Header: Authorization: Bearer {token}
Content-Type: multipart/form-data
Parameters:

voice_file: (파일) 음성 파일

응답 예시:
jsonCopy{
  "broadcast": {
    "id": 1,
    "user_id": 1,
    "active": true,
    "expired_at": "2023-03-01T12:00:00Z",
    "created_at": "2023-02-23T12:00:00Z",
    "updated_at": "2023-02-23T12:00:00Z"
  }
}
브로드캐스트 상세 조회
URL: /api/broadcasts/{id}
Method: GET
Header: Authorization: Bearer {token}
응답 예시:
jsonCopy{
  "id": 1,
  "user_id": 1,
  "active": true,
  "expired_at": "2023-03-01T12:00:00Z",
  "created_at": "2023-02-23T12:00:00Z",
  "updated_at": "2023-02-23T12:00:00Z",
  "user": {
    "id": 1,
    "nickname": "User1",
    "gender": "male"
  }
}
브로드캐스트에 답장하기
URL: /api/broadcasts/{id}/reply
Method: POST
Header: Authorization: Bearer {token}
Content-Type: multipart/form-data
Parameters:

voice_file: (파일) 음성 파일

응답 예시:
jsonCopy{
  "message": "답장 완료",
  "conversation_id": 1
}
대화 API
대화 목록 조회
URL: /api/conversations
Method: GET
Header: Authorization: Bearer {token}
응답 예시:
jsonCopy[
  {
    "id": 1,
    "user_a_id": 1,
    "user_b_id": 2,
    "active": true,
    "favorite": false,
    "created_at": "2023-02-23T12:00:00Z",
    "updated_at": "2023-02-23T12:00:00Z",
    "user_a": {
      "id": 1,
      "nickname": "User1",
      "gender": "male"
    },
    "user_b": {
      "id": 2,
      "nickname": "User2",
      "gender": "female"
    }
  }
]
대화 상세 조회
URL: /api/conversations/{id}
Method: GET
Header: Authorization: Bearer {token}
응답 예시:
jsonCopy{
  "conversation": {
    "id": 1,
    "user_a_id": 1,
    "user_b_id": 2,
    "active": true,
    "favorite": false,
    "created_at": "2023-02-23T12:00:00Z",
    "updated_at": "2023-02-23T12:00:00Z"
  },
  "messages": [
    {
      "id": 1,
      "conversation_id": 1,
      "sender_id": 1,
      "read": false,
      "created_at": "2023-02-23T12:00:00Z",
      "updated_at": "2023-02-23T12:00:00Z",
      "sender": {
        "id": 1,
        "nickname": "User1"
      }
    }
  ]
}
대화방 메시지 전송
URL: /api/conversations/{id}/send_message
Method: POST
Header: Authorization: Bearer {token}
Content-Type: multipart/form-data
Parameters:

voice_file: (파일) 음성 파일

응답 예시:
jsonCopy{
  "message": "메시지 전송 완료",
  "message_id": 1
}
대화방 즐겨찾기 등록
URL: /api/conversations/{id}/favorite
Method: POST
Header: Authorization: Bearer {token}
응답 예시:
jsonCopy{
  "message": "즐겨찾기 등록 완료"
}
대화방 즐겨찾기 해제
URL: /api/conversations/{id}/unfavorite
Method: POST
Header: Authorization: Bearer {token}
응답 예시:
jsonCopy{
  "message": "즐겨찾기 해제 완료"
}
대화방 삭제
URL: /api/conversations/{id}
Method: DELETE
Header: Authorization: Bearer {token}
응답 예시:
jsonCopy{
  "message": "대화방이 삭제되었습니다."
}
사용자 API
사용자 차단
URL: /users/{id}/block
Method: POST
Header: Authorization: Bearer {token}
응답 예시:
jsonCopy{
  "message": "차단 완료",
  "block": {
    "id": 1,
    "blocker_id": 1,
    "blocked_id": 2,
    "created_at": "2023-02-23T12:00:00Z",
    "updated_at": "2023-02-23T12:00:00Z"
  }
}
사용자 차단 해제
URL: /users/{id}/unblock
Method: POST
Header: Authorization: Bearer {token}
응답 예시:
jsonCopy{
  "message": "차단 해제 완료"
}
사용자 신고하기
URL: /users/{id}/report
Method: POST
Header: Authorization: Bearer {token}
Parameters:
jsonCopy{
  "reason": "부적절한 내용"
}
응답 예시:
jsonCopy{
  "message": "신고 완료",
  "report": {
    "id": 1,
    "reporter_id": 1,
    "reported_id": 2,
    "reason": "부적절한 내용",
    "created_at": "2023-02-23T12:00:00Z",
    "updated_at": "2023-02-23T12:00:00Z"
  }
}
에러 응답 형식
모든 API는 에러 발생 시 아래와 같은 일관된 형식으로 응답합니다:
인증 오류 (401)
jsonCopy{
  "error": "Invalid token"
}
권한 오류 (403)
jsonCopy{
  "error": "Unauthorized access"
}
리소스 없음 (404)
jsonCopy{
  "error": "Resource not found"
}
유효성 검증 오류 (422)
jsonCopy{
  "error": "Validation error",
  "details": "전화번호 형식이 올바르지 않습니다"
}
서버 오류 (500)
jsonCopy{
  "error": "Server error"
}
