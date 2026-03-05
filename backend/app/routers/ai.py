"""
AI 요약 라우터
OpenAI GPT-4o-mini를 사용하여 일일 보고를 자연스러운 문장으로 정리
API 키는 서버 환경변수(OPENAI_API_KEY)에서 읽음 → 클라이언트에 노출 없음
"""
import os
import httpx
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from ..auth import get_current_user
from ..models import User

router = APIRouter(prefix="/ai", tags=["ai"])

_OPENAI_ENDPOINT = "https://api.openai.com/v1/chat/completions"


# ── 요청 바디 ─────────────────────────────────────────
class AiSummaryRequest(BaseModel):
    date: str          # "YYYY-MM-DD"
    report_text: str   # 클라이언트에서 만든 원본 보고 데이터 텍스트


# ── AI 요약 엔드포인트 ────────────────────────────────
@router.post("/summarize")
async def summarize(
    body: AiSummaryRequest,
    _: User = Depends(get_current_user),
):
    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key or not api_key.startswith("sk-"):
        raise HTTPException(status_code=503, detail="AI 요약 서비스가 설정되지 않았습니다.")

    # 날짜 파싱
    try:
        dt = datetime.strptime(body.date, "%Y-%m-%d")
        date_label = f"{dt.year}년 {dt.month}월 {dt.day}일"
    except ValueError:
        date_label = body.date

    prompt = f"""아래는 {date_label}의 부서별 업무 현황 원본 데이터입니다.
이를 원장님께 보고드리는 공식 일일 업무 보고서 형식으로 깔끔하게 정리해 주세요.

{body.report_text}

[보고서 작성 요청 사항]
1. 제목: "{date_label} 일일 업무 보고" 형식으로 시작해 주세요.
2. 전체 요약을 첫 문단(2~3줄)으로 작성해 주세요.
3. 부서별로 완료 업무와 진행 상황을 공손하고 간결한 경어체로 정리해 주세요.
4. 담당자 이름이 있으면 꼭 언급해 주세요.
5. 보고 내용(→)이 있으면 핵심만 자연스럽게 녹여 주세요.
6. 전체 분량은 20줄 이내로 간결하게 작성해 주세요.
7. 마지막은 "이상 보고 드립니다." 로 마무리해 주세요.
8. 반드시 한국어 경어체로 작성해 주세요."""

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            _OPENAI_ENDPOINT,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
            json={
                "model": "gpt-4o-mini",
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "당신은 기업 내부 업무 보고서를 정리하는 전문 비서입니다. "
                            "원장님(최고 경영자)께 드리는 일일 업무 보고서를 작성합니다. "
                            "공손하고 명확한 한국어 경어체를 사용하며, 핵심 내용을 간결하고 체계적으로 전달합니다. "
                            "당일 완료된 업무와 중간보고가 있는 진행중 업무만 포함하여 보고서를 작성합니다."
                        ),
                    },
                    {"role": "user", "content": prompt},
                ],
                "max_tokens": 1200,
                "temperature": 0.3,
            },
        )

    if response.status_code == 200:
        data = response.json()
        text = data["choices"][0]["message"]["content"].strip()
        return {"summary": text}
    elif response.status_code == 401:
        raise HTTPException(status_code=502, detail="OpenAI API 키가 유효하지 않습니다.")
    elif response.status_code == 429:
        raise HTTPException(status_code=429, detail="API 요청 한도를 초과했습니다. 잠시 후 다시 시도해 주세요.")
    else:
        err = response.json().get("error", {}).get("message", "알 수 없는 오류")
        raise HTTPException(status_code=502, detail=f"AI 요약 실패: {err}")
