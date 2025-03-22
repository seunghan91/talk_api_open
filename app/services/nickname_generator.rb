class NicknameGenerator
  # 명사 목록 (생성될 닉네임에 사용될 첫 단어)
  FIRST_WORDS = %w[
    행복한 즐거운 신나는 귀여운 멋진 화려한 웃는 매력적인 활기찬
    따뜻한 명랑한 기분좋은 환상적인 영리한 엉뚱한 재미있는 사랑스러운
    용감한 똑똑한 부지런한 늠름한 훌륭한 소중한 깜찍한 상냥한 푸른
  ]

  # 명사 목록 (생성될 닉네임에 사용될 두번째 단어)
  SECOND_WORDS = %w[
    토끼 호랑이 강아지 고양이 코끼리 사자 표범 판다 여우 늑대
    곰 기린 하마 앵무새 코알라 펭귄 거북이 원숭이 너구리 다람쥐
    독수리 공룡 해달 물개 얼룩말 꽃사슴 악어 고래 상어 돌고래
  ]

  # 세번째 단어 (선택적으로 사용)
  THIRD_WORDS = %w[
    친구 천사 요정 꿈나무 마법사 용사 영웅 기사 왕자 공주
    대장 선생님 박사 대표 가수 우주인 요리사 화가 감독 작가
  ]

  # 2개 또는 3개 단어를 무작위로 조합하여 닉네임 생성
  def self.generate
    if [ true, false ].sample
      # 세 단어 조합 (30% 확률)
      if rand < 0.3
        "#{FIRST_WORDS.sample}#{SECOND_WORDS.sample}#{THIRD_WORDS.sample}"
      # 두 단어 조합 (70% 확률)
      else
        "#{FIRST_WORDS.sample}#{SECOND_WORDS.sample}"
      end
    else
      # 두 단어 조합 (100%)
      "#{FIRST_WORDS.sample}#{SECOND_WORDS.sample}"
    end
  end

  # 생성된 닉네임이 이미 존재하는지 확인하고, 존재하면 새로 생성
  def self.generate_unique
    attempts = 0
    loop do
      nickname = generate
      return nickname unless User.exists?(nickname: nickname)

      attempts += 1
      # 10번 시도해도 안되면 타임스탬프 추가
      if attempts >= 10
        return "#{nickname}#{Time.now.to_i % 1000}"
      end
    end
  end
end
