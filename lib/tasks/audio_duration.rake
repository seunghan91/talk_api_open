namespace :audio do
  desc "오디오 파일의 재생 시간을 추출하여 Broadcast와 Message의 duration 필드 업데이트"
  task update_durations: :environment do
    # 모델별 성공/실패 횟수 추적
    broadcast_success = 0
    broadcast_skipped = 0
    broadcast_error = 0
    message_success = 0
    message_skipped = 0
    message_error = 0

    puts "===== 브로드캐스트 오디오 재생 시간 업데이트 ====="
    # 음성 파일이 첨부된 모든 Broadcast 처리
    Broadcast.where(duration: [nil, 0]).find_each do |broadcast|
      if broadcast.audio.attached?
        begin
          # 음성 파일 정보 추출
          audio_info = AudioProcessorService.get_audio_info(broadcast.audio.blob.service.path_for(broadcast.audio.key))
          
          if audio_info && audio_info[:duration]
            # 반올림하여 정수로 저장 (초 단위)
            duration = audio_info[:duration].round
            broadcast.update_column(:duration, duration)
            puts "브로드캐스트 ID #{broadcast.id}: duration #{duration}초로 설정"
            broadcast_success += 1
          else
            puts "브로드캐스트 ID #{broadcast.id}: 오디오 정보를 추출할 수 없음"
            broadcast_error += 1
          end
        rescue => e
          puts "브로드캐스트 ID #{broadcast.id} 처리 중 오류 발생: #{e.message}"
          broadcast_error += 1
        end
      else
        puts "브로드캐스트 ID #{broadcast.id}: 오디오 파일 없음"
        broadcast_skipped += 1
      end
    end

    puts "\n===== 메시지 오디오 재생 시간 업데이트 ====="
    # 음성 파일이 첨부된 모든 Message 처리
    Message.where(duration: [nil, 0]).find_each do |message|
      if message.voice_file.attached?
        begin
          # 음성 파일 정보 추출
          audio_info = AudioProcessorService.get_audio_info(message.voice_file.blob.service.path_for(message.voice_file.key))
          
          if audio_info && audio_info[:duration]
            # 반올림하여 정수로 저장 (초 단위)
            duration = audio_info[:duration].round
            message.update_column(:duration, duration)
            puts "메시지 ID #{message.id}: duration #{duration}초로 설정"
            message_success += 1
          else
            puts "메시지 ID #{message.id}: 오디오 정보를 추출할 수 없음"
            message_error += 1
          end
        rescue => e
          puts "메시지 ID #{message.id} 처리 중 오류 발생: #{e.message}"
          message_error += 1
        end
      else
        puts "메시지 ID #{message.id}: 음성 파일 없음"
        message_skipped += 1
      end
    end

    puts "\n===== 작업 요약 ====="
    puts "브로드캐스트: 성공 #{broadcast_success}건, 스킵 #{broadcast_skipped}건, 오류 #{broadcast_error}건"
    puts "메시지: 성공 #{message_success}건, 스킵 #{message_skipped}건, 오류 #{message_error}건"
  end
end 