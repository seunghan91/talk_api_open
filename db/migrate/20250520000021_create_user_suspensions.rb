class CreateUserSuspensions < ActiveRecord::Migration[7.0]
  def change
    create_table :user_suspensions do |t|
      t.references :user, null: false, foreign_key: true, comment: '정지된 사용자 외래키'
      t.string :reason, comment: '정지 사유'
      t.datetime :suspended_at, comment: '정지 시작 시간'
      t.datetime :suspended_until, comment: '정지 만료 시간'
      t.string :suspended_by, default: 'system', comment: '정지 집행자 (시스템/관리자)'
      t.boolean :active, default: true, comment: '현재 활성 정지 여부'

      t.timestamps
    end

    # 정지 만료 시간 기반 인덱스 (배치 처리용)
    add_index :user_suspensions, [:active, :suspended_until], name: 'index_user_suspensions_on_active_and_until'
    
    # 사용자 경고 카운트 필드 추가 
    add_column :users, :warning_count, :integer, default: 0, comment: '사용자 경고 누적 횟수'
  end
end
