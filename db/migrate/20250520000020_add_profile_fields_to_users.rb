class AddProfileFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    # 연령대 추가 - 기본값 없음 (미선택 상태에서 시작)
    add_column :users, :age_group, :string, comment: '사용자 연령대: 20s, 30s, 40s, 50s'

    # 지역 추가 - 기본값 없음 (미선택 상태에서 시작)
    add_column :users, :region, :string, comment: '사용자 지역: 국가/시도 형식'

    # 프로필 완료 여부 플래그 (추후 프로필 항목 추가 시 필요)
    add_column :users, :profile_completed, :boolean, default: false

    # 연령대 + 성별 기반 검색용 인덱스 (추후 필터링 사용)
    add_index :users, [ :gender, :age_group ], name: 'index_users_on_gender_and_age'

    # 지역 기반 검색용 인덱스 (추후 필터링 사용)
    add_index :users, :region, name: 'index_users_on_region'
  end
end
