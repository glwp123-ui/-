"""
초기 시드 데이터 생성 (최초 1회)
"""
from datetime import datetime, timedelta
from uuid import uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from .models import User, Department, Task, Report, UserRole, TaskStatus, TaskPriority
from .auth import hash_password


async def seed_if_empty(db: AsyncSession):
    # 이미 데이터가 있으면 스킵
    count = await db.execute(select(func.count()).select_from(User))
    if count.scalar() > 0:
        return

    now = datetime.utcnow()
    m   = datetime(now.year, now.month, 1)  # 이번 달 1일

    def md(day: int) -> datetime:
        import calendar
        last = calendar.monthrange(m.year, m.month)[1]
        return datetime(m.year, m.month, min(day, last))

    # ── 기본 계정 ─────────────────────────────────────
    users = [
        User(id=str(uuid4()), username="master", password=hash_password("master1234"),
             display_name="원장님",    role=UserRole.master, is_active=True, created_at=now),
        User(id=str(uuid4()), username="admin",  password=hash_password("admin1234"),
             display_name="관리자",    role=UserRole.admin,  is_active=True, created_at=now),
        User(id=str(uuid4()), username="user1",  password=hash_password("user1234"),
             display_name="내과 담당자", role=UserRole.user,  is_active=True, created_at=now),
    ]
    db.add_all(users)

    # ── 부서 ──────────────────────────────────────────
    dept_data = [
        ("내과",       "🫀", "내과 진료 및 입원 환자 관리",       "김내과"),
        ("외과",       "🔪", "외과 수술 및 처치",                 "이외과"),
        ("응급의학과", "🚨", "응급 환자 처치 및 중증 관리",        "박응급"),
        ("간호팀",     "💉", "병동 간호 및 환자 케어",             "최수간호"),
        ("원무팀",     "🏥", "환자 접수·수납·보험 청구",           "정원무"),
        ("약제팀",     "💊", "조제 및 의약품 관리",               "한약사"),
    ]
    depts = [
        Department(id=str(uuid4()), name=n, emoji=e, description=d,
                   manager_name=m_, created_at=now)
        for n, e, d, m_ in dept_data
    ]
    db.add_all(depts)

    # ── 업무 (달력에 표시될 마감일 포함) ──────────────
    task_data = [
        # 내과
        dict(title="당뇨 환자 식단 프로그램 검토", desc="입원 당뇨 환자 맞춤 식이요법 가이드라인 갱신",
             di=0, status=TaskStatus.inProgress, pri=TaskPriority.high,
             sd=md(3), dd=md(8),   assignee="김민준"),
        dict(title="고혈압 클리닉 운영 계획", desc="분기별 고혈압 클리닉 일정 및 담당 의사 배정",
             di=0, status=TaskStatus.notStarted, pri=TaskPriority.medium,
             sd=md(12), dd=md(18), assignee="이서준"),
        dict(title="내시경실 장비 점검", desc="내시경 소독 및 장비 이상 유무 확인",
             di=0, status=TaskStatus.done, pri=TaskPriority.high,
             sd=None, dd=md(5),   assignee="박지호"),
        dict(title="내과 월간 케이스 컨퍼런스", desc="이달 주요 증례 발표 및 토의",
             di=0, status=TaskStatus.notStarted, pri=TaskPriority.low,
             sd=None, dd=md(25),  assignee="최진우"),
        # 외과
        dict(title="수술실 소독 프로토콜 업데이트", desc="최신 감염관리 지침에 따른 수술실 소독 절차 개정",
             di=1, status=TaskStatus.inProgress, pri=TaskPriority.high,
             sd=md(2), dd=md(7),   assignee="정수현"),
        dict(title="복강경 수술 스케줄 조정", desc="이번 달 복강경 수술 예약 현황 점검 및 OR 배정",
             di=1, status=TaskStatus.notStarted, pri=TaskPriority.medium,
             sd=md(15), dd=md(20), assignee="강태양"),
        dict(title="외과 합병증 케이스 리뷰", desc="지난 분기 외과 합병증 사례 분석 및 개선안 도출",
             di=1, status=TaskStatus.done, pri=TaskPriority.low,
             sd=None, dd=md(3),   assignee="윤하은"),
        dict(title="외과 신규 장비 도입 검토", desc="최소침습 수술 장비 견적 및 도입 일정 계획",
             di=1, status=TaskStatus.notStarted, pri=TaskPriority.medium,
             sd=md(22), dd=md(28), assignee="박재훈"),
        # 응급의학과
        dict(title="응급 트리아지 기준 재교육", desc="전체 응급실 스태프 대상 트리아지 기준 재교육 실시",
             di=2, status=TaskStatus.inProgress, pri=TaskPriority.high,
             sd=md(4), dd=md(10),  assignee="임채원"),
        dict(title="제세동기 배터리 교체", desc="응급실 내 AED·제세동기 배터리 일제 점검",
             di=2, status=TaskStatus.notStarted, pri=TaskPriority.high,
             sd=None, dd=md(14),  assignee="한소율"),
        dict(title="응급실 감염병 대응 매뉴얼 갱신", desc="최신 질병청 지침 반영한 감염병 대응 SOP 개정",
             di=2, status=TaskStatus.notStarted, pri=TaskPriority.medium,
             sd=md(18), dd=md(24), assignee="오준혁"),
        # 간호팀
        dict(title="신규 간호사 OJT 프로그램 준비", desc="신규 간호사 현장 교육 커리큘럼 작성",
             di=3, status=TaskStatus.done, pri=TaskPriority.high,
             sd=None, dd=md(6),   assignee="조민서"),
        dict(title="병동 근무표 작성", desc="간호사 3교대 근무표 초안 작성 및 배포",
             di=3, status=TaskStatus.inProgress, pri=TaskPriority.medium,
             sd=md(9), dd=md(13),  assignee="배나연"),
        dict(title="낙상 예방 캠페인 자료 제작", desc="병동 내 낙상 예방 포스터 및 환자 안내문 업데이트",
             di=3, status=TaskStatus.notStarted, pri=TaskPriority.low,
             sd=md(20), dd=md(27), assignee="오현우"),
        dict(title="간호 평가 기록 정리", desc="월말 간호 평가 기록 취합 및 서류 정리",
             di=3, status=TaskStatus.notStarted, pri=TaskPriority.medium,
             sd=None, dd=md(30),  assignee="이나라"),
        # 원무팀
        dict(title="건강보험 청구 오류 수정", desc="이번 달 청구 반려 건 원인 분석 및 재청구",
             di=4, status=TaskStatus.inProgress, pri=TaskPriority.high,
             sd=md(1), dd=md(9),   assignee="나예진"),
        dict(title="원무 전산 시스템 업그레이드", desc="HIS 시스템 버전 업그레이드 일정 조율 및 테스트",
             di=4, status=TaskStatus.notStarted, pri=TaskPriority.medium,
             sd=md(16), dd=md(22), assignee="류상현"),
        dict(title="월말 수납 실적 집계", desc="월 수납 현황 집계 및 원장 보고용 자료 작성",
             di=4, status=TaskStatus.notStarted, pri=TaskPriority.high,
             sd=None, dd=md(28),  assignee="서지원"),
        # 약제팀
        dict(title="마약류 재고 실사", desc="월말 마약류 의약품 재고 현황 실사 및 보고",
             di=5, status=TaskStatus.done, pri=TaskPriority.high,
             sd=None, dd=md(4),   assignee="송약사"),
        dict(title="항생제 사용 지침 배포", desc="내성 예방을 위한 항생제 처방 가이드라인 전과 배포",
             di=5, status=TaskStatus.inProgress, pri=TaskPriority.medium,
             sd=md(11), dd=md(16), assignee="문약사"),
        dict(title="의약품 유효기간 일제 점검", desc="전체 병동 비치 의약품 유효기간 확인 및 폐기 처리",
             di=5, status=TaskStatus.notStarted, pri=TaskPriority.medium,
             sd=md(19), dd=md(23), assignee="권약사"),
        dict(title="조제 오류 예방 교육", desc="약제팀 전체 조제 실수 사례 공유 및 예방 교육",
             di=5, status=TaskStatus.notStarted, pri=TaskPriority.low,
             sd=None, dd=md(26),  assignee="김약무"),
    ]

    tasks = []
    for td in task_data:
        t = Task(
            id=str(uuid4()),
            title=td["title"], description=td["desc"],
            dept_id=depts[td["di"]].id,
            status=td["status"], priority=td["pri"],
            assignee_name=td["assignee"],
            start_date=td["sd"], due_date=td["dd"],
            created_at=now, updated_at=now,
        )
        tasks.append(t)
    db.add_all(tasks)

    # ── 샘플 보고 ──────────────────────────────────────
    sample_reports = [
        Report(id=str(uuid4()), task_id=tasks[0].id,
               content="1차 검토 완료. 저탄수화물 식이 중심으로 안 작성 중.",
               reporter_name="김민준", created_at=now - timedelta(days=1), updated_at=now),
        Report(id=str(uuid4()), task_id=tasks[4].id,
               content="소독 프로토콜 초안 완성. 감염관리팀 검토 요청 예정.",
               reporter_name="정수현", created_at=now - timedelta(days=1), updated_at=now),
        Report(id=str(uuid4()), task_id=tasks[8].id,
               content="1차 교육 완료 (응급실 전담 팀). 2차 교육 다음 주 예정.",
               reporter_name="임채원", created_at=now,                    updated_at=now),
    ]
    db.add_all(sample_reports)

    await db.commit()
    print("✅ 시드 데이터 생성 완료")
