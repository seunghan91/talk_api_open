/**
 * 시간 포맷 (상대 시간)
 */
export function timeAgo(dateString) {
  const date = new Date(dateString);
  const now = new Date();
  const diff = Math.floor((now - date) / 1000);

  if (diff < 60) return "방금 전";
  if (diff < 3600) return `${Math.floor(diff / 60)}분 전`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}시간 전`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}일 전`;

  return date.toLocaleDateString("ko-KR", { month: "short", day: "numeric" });
}

/**
 * 초를 mm:ss 형식으로 변환
 */
export function formatDuration(seconds) {
  if (!seconds) return "0:00";
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs.toString().padStart(2, "0")}`;
}

/**
 * 전화번호 마스킹
 */
export function maskPhone(phone) {
  if (!phone) return "";
  return `${phone.slice(0, 3)}****${phone.slice(-4)}`;
}

/**
 * 익명 아바타 동물 이모지 매핑
 */
const ANIMAL_EMOJIS = [
  "🦊", "🐻", "🐧", "🐰", "🦁", "🐸", "🐱", "🐶",
  "🦄", "🐼", "🐨", "🦋", "🐬", "🦜", "🐙", "🦝",
];

export function getAnimalEmoji(userId) {
  if (!userId) return "👤";
  const index = typeof userId === "number"
    ? userId % ANIMAL_EMOJIS.length
    : userId.toString().charCodeAt(0) % ANIMAL_EMOJIS.length;
  return ANIMAL_EMOJIS[index];
}

/**
 * 익명 닉네임에서 동물 이름 추출
 */
export function getAnimalName(nickname) {
  return nickname || "익명의 사용자";
}

/**
 * CSS 클래스 결합 유틸리티
 */
export function cn(...classes) {
  return classes.filter(Boolean).join(" ");
}
