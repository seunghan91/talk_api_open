require 'swagger_helper'

RSpec.describe 'API V1 Reports', type: :request do
  path '/api/v1/reports' do
    get '사용자 신고 목록 조회' do
      tags 'Reports'
      security [ bearer_auth: [] ]
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false, description: '페이지 번호'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: '페이지당 결과 수'

      response '200', '성공적으로 신고 목록을 조회함' do
        schema type: :object, properties: {
          reports: {
            type: :array,
            items: { '$ref': '#/components/schemas/report' }
          },
          meta: {
            type: :object,
            properties: {
              current_page: { type: :integer },
              total_pages: { type: :integer },
              total_count: { type: :integer }
            }
          }
        }
        run_test!
      end

      response '401', '인증 실패' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end
    end

    post '신고 생성' do
      tags 'Reports'
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :report_params, in: :body, schema: {
        type: :object,
        properties: {
          report: {
            type: :object,
            properties: {
              reported_id: { type: :integer, description: '신고할 사용자 ID' },
              report_type: { type: :string, enum: [ 'user', 'broadcast', 'message' ], description: '신고 유형' },
              reason: { type: :string, enum: [ 'gender_impersonation', 'inappropriate_content', 'spam', 'harassment', 'other' ], description: '신고 사유' },
              related_id: { type: :integer, nullable: true, description: '관련 브로드캐스트/메시지 ID (report_type이 user가 아닌 경우 필수)' }
            },
            required: [ 'reported_id', 'report_type', 'reason' ]
          }
        },
        required: [ 'report' ]
      }

      response '201', '신고가 성공적으로 생성됨' do
        schema type: :object, properties: {
          report: { '$ref': '#/components/schemas/report' },
          message: { type: :string }
        }
        run_test!
      end

      response '400', '잘못된 요청 파라미터' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end

      response '401', '인증 실패' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end

      response '422', '처리할 수 없는 엔티티' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end
    end
  end

  path '/api/v1/reports/{id}' do
    parameter name: :id, in: :path, type: :integer, description: '신고 ID'

    get '신고 상세 조회' do
      tags 'Reports'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', '성공적으로 신고를 조회함' do
        schema type: :object, properties: {
          report: { '$ref': '#/components/schemas/report' }
        }
        run_test!
      end

      response '401', '인증 실패' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end

      response '404', '신고를 찾을 수 없음' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/block' do
    parameter name: :id, in: :path, type: :integer, description: '차단할 사용자 ID'

    post '사용자 차단' do
      tags 'Users', 'Blocking'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', '성공적으로 사용자를 차단함' do
        schema type: :object, properties: {
          message: { type: :string },
          blocked: { type: :boolean }
        }
        run_test!
      end

      response '401', '인증 실패' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end

      response '404', '사용자를 찾을 수 없음' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end

      response '422', '처리할 수 없는 엔티티' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end
    end
  end

  # 자신의 차단 목록 조회
  path '/api/v1/users/blocks' do
    get '내가 차단한 사용자 목록 조회' do
      tags 'Users', 'Blocking'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', '성공적으로 차단 목록을 조회함' do
        schema type: :object, properties: {
          blocks: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                blocked_id: { type: :integer },
                created_at: { type: :string, format: 'date-time' },
                blocked_user: { '$ref': '#/components/schemas/user' }
              }
            }
          }
        }
        run_test!
      end

      response '401', '인증 실패' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end
    end
  end

  # 사용자 차단 해제
  path '/api/v1/users/{id}/unblock' do
    parameter name: :id, in: :path, type: :integer, description: '차단 해제할 사용자 ID'

    post '사용자 차단 해제' do
      tags 'Users', 'Blocking'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', '성공적으로 사용자 차단을 해제함' do
        schema type: :object, properties: {
          message: { type: :string },
          unblocked: { type: :boolean }
        }
        run_test!
      end

      response '401', '인증 실패' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end

      response '404', '사용자 또는 차단 기록을 찾을 수 없음' do
        schema '$ref': '#/components/schemas/error_response'
        run_test!
      end
    end
  end
end
