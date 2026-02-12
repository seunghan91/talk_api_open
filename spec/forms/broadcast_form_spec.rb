require 'rails_helper'

RSpec.describe BroadcastForm do
  let(:user) { create(:user) }
  let(:mock_audio_service) { instance_double(AudioUploadService) }
  let(:mock_recipient_service) { instance_double(Broadcasts::RecipientSelectionService) }

  before do
    allow(AudioUploadService).to receive(:new).and_return(mock_audio_service)
    allow(mock_audio_service).to receive(:upload).and_return('https://example.com/audio.m4a')

    allow(Broadcasts::RecipientSelectionService).to receive(:new).and_return(mock_recipient_service)
    allow(mock_recipient_service).to receive(:with_filters).and_return(mock_recipient_service)
    allow(mock_recipient_service).to receive(:select_recipients).and_return([1, 2, 3, 4, 5])
  end

  describe '#valid?' do
    let(:valid_params) do
      {
        user_id: user.id,
        audio_file: fixture_file_upload('audio_sample.m4a', 'audio/mp4'),
        duration: 30,
        recipient_count: 5,
        recipient_filters: {
          gender: 'all',
          age_group: 'all',
          region: 'all'
        }
      }
    end

    context '유효한 파라미터일 때' do
      it 'true를 반환한다' do
        form = described_class.new(valid_params)
        expect(form.valid?).to be true
      end
    end

    context '필수 필드가 누락되었을 때' do
      it 'user_id가 없으면 유효하지 않다' do
        form = described_class.new(valid_params.except(:user_id))
        expect(form.valid?).to be false
        expect(form.errors[:user_id]).to include("can't be blank")
      end

      it 'audio_file이 없으면 유효하지 않다' do
        form = described_class.new(valid_params.except(:audio_file))
        expect(form.valid?).to be false
        expect(form.errors[:audio_file]).to include("can't be blank")
      end
    end

    context '오디오 파일 검증' do
      it '지원하지 않는 형식은 거부한다' do
        params = valid_params.merge(
          audio_file: fixture_file_upload('sample.txt', 'text/plain')
        )
        form = described_class.new(params)

        expect(form.valid?).to be false
        expect(form.errors[:audio_file]).to include('지원하지 않는 파일 형식입니다')
      end

      it '최대 크기를 초과하면 거부한다' do
        large_file = double('file', size: 11.megabytes, content_type: 'audio/mp4')
        params = valid_params.merge(audio_file: large_file)
        form = described_class.new(params)

        expect(form.valid?).to be false
        expect(form.errors[:audio_file]).to include('파일 크기는 10MB 이하여야 합니다')
      end
    end

    context 'duration 검증' do
      it '60초를 초과하면 거부한다' do
        form = described_class.new(valid_params.merge(duration: 61))
        expect(form.valid?).to be false
        expect(form.errors[:duration]).to include('60초 이하여야 합니다')
      end

      it '0 이하면 거부한다' do
        form = described_class.new(valid_params.merge(duration: 0))
        expect(form.valid?).to be false
        expect(form.errors[:duration]).to be_present
      end
    end

    context 'recipient_count 검증' do
      it '최대값을 초과하면 거부한다' do
        form = described_class.new(valid_params.merge(recipient_count: 101))
        expect(form.valid?).to be false
        expect(form.errors[:recipient_count]).to include('100명 이하여야 합니다')
      end

      it '1 미만이면 거부한다' do
        form = described_class.new(valid_params.merge(recipient_count: 0))
        expect(form.valid?).to be false
        expect(form.errors[:recipient_count]).to be_present
      end
    end
  end

  describe '#save' do
    let(:recipients) { create_list(:user, 5) }
    let(:recipient_ids) { recipients.map(&:id) }
    let(:valid_params) do
      {
        user_id: user.id,
        audio_file: fixture_file_upload('audio_sample.m4a', 'audio/mp4'),
        duration: 30,
        recipient_count: 5,
        recipient_filters: {
          gender: 'male',
          age_group: '20s',
          region: '서울'
        }
      }
    end

    before do
      allow(BroadcastDeliveryJob).to receive(:perform_later)
      allow(mock_recipient_service).to receive(:select_recipients).and_return(recipient_ids)
    end

    context '유효한 데이터일 때' do
      it '방송을 생성한다' do
        form = described_class.new(valid_params)

        result = form.save
        expect(result).to be true
        expect(form.broadcast).to be_persisted
      end

      it '오디오 파일을 업로드한다' do
        form = described_class.new(valid_params)
        result = form.save

        expect(result).to be true
        expect(mock_audio_service).to have_received(:upload)
      end

      it '수신자를 선택한다' do
        form = described_class.new(valid_params)
        form.save

        expect(form.recipient_ids).to eq(recipient_ids)
      end
    end

    context '유효하지 않은 데이터일 때' do
      it 'false를 반환한다' do
        form = described_class.new(user_id: nil)
        expect(form.save).to be false
      end

      it '방송을 생성하지 않는다' do
        form = described_class.new(user_id: nil)

        expect {
          form.save
        }.not_to change(Broadcast, :count)
      end
    end

    context '트랜잭션 처리' do
      it '오류 발생 시 롤백한다' do
        allow(mock_audio_service).to receive(:upload).and_raise(StandardError, 'Upload failed')

        form = described_class.new(valid_params)

        expect {
          form.save
        }.not_to change(Broadcast, :count)

        expect(form.errors[:base]).to include('방송 생성 중 오류가 발생했습니다')
      end
    end
  end

  describe '#to_broadcast_params' do
    let(:form) do
      described_class.new(
        user_id: user.id,
        audio_file: fixture_file_upload('audio_sample.m4a', 'audio/mp4'),
        duration: 30,
        recipient_count: 5
      )
    end

    it '방송 생성에 필요한 파라미터를 반환한다' do
      form.valid?

      params = form.to_broadcast_params

      expect(params).to include(
        user_id: user.id,
        duration: 30,
        active: true
      )
      expect(params[:expired_at]).to be_present
    end
  end

  describe '의존성 주입' do
    it '커스텀 서비스를 주입받을 수 있다' do
      custom_audio_service = double('AudioUploadService')
      custom_recipient_service = double('RecipientSelectionService')

      allow(BroadcastDeliveryJob).to receive(:perform_later)

      form = described_class.new(
        user_id: user.id,
        audio_file: fixture_file_upload('audio_sample.m4a', 'audio/mp4'),
        duration: 30,
        recipient_count: 5,
        audio_upload_service: custom_audio_service,
        recipient_selection_service: custom_recipient_service
      )

      expect(custom_audio_service).to receive(:upload).and_return('https://example.com/audio.m4a')
      expect(custom_recipient_service).to receive(:select_recipients).and_return([1, 2, 3])

      form.save
    end
  end
end
