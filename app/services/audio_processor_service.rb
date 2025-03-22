class AudioProcessorService
  require "open3"

  # 무음 구간 자동 트리밍
  def self.trim_silence(input_file, output_file = nil)
    # 출력 파일이 지정되지 않은 경우 임시 파일 생성
    output_file ||= "#{Dir.tmpdir}/trimmed_#{File.basename(input_file)}"

    # FFmpeg 명령어 구성
    # -af silenceremove: 무음 구간 제거 필터
    # 1:0:-50dB: 시작 부분의 무음 제거 (1=제거, 0=무음 길이, -50dB=무음 임계값)
    # 1:0:-50dB: 끝 부분의 무음 제거 (1=제거, 0=무음 길이, -50dB=무음 임계값)
    command = [
      "ffmpeg",
      "-i", input_file,
      "-af", "silenceremove=1:0:-50dB:1:0:-50dB",
      "-c:a", "aac",
      "-b:a", "128k",
      "-y",  # 기존 파일 덮어쓰기
      output_file
    ]

    # 명령어 실행
    Rails.logger.info("무음 구간 제거 명령어 실행: #{command.join(' ')}")

    stdout, stderr, status = Open3.capture3(*command)

    if status.success?
      Rails.logger.info("무음 구간 제거 성공: #{output_file}")
      output_file
    else
      Rails.logger.error("무음 구간 제거 실패: #{stderr}")
      nil
    end
  end

  # 오디오 정보 가져오기
  def self.get_audio_info(file_path)
    command = [
      "ffprobe",
      "-v", "error",
      "-show_entries", "format=duration,size",
      "-show_entries", "stream=codec_name,channels,sample_rate",
      "-of", "json",
      file_path
    ]

    stdout, stderr, status = Open3.capture3(*command)

    if status.success?
      info = JSON.parse(stdout)

      duration = info.dig("format", "duration").to_f
      size = info.dig("format", "size").to_i
      codec = info.dig("streams", 0, "codec_name")
      channels = info.dig("streams", 0, "channels").to_i
      sample_rate = info.dig("streams", 0, "sample_rate").to_i

      {
        duration: duration,
        size: size,
        codec: codec,
        channels: channels,
        sample_rate: sample_rate
      }
    else
      Rails.logger.error("오디오 정보 가져오기 실패: #{stderr}")
      nil
    end
  end

  # 오디오 파일 변환 (포맷 통일)
  def self.convert_audio(input_file, output_format = "m4a")
    output_file = "#{Dir.tmpdir}/converted_#{File.basename(input_file, '.*')}.#{output_format}"

    command = [
      "ffmpeg",
      "-i", input_file,
      "-c:a", "aac",
      "-b:a", "128k",
      "-y",
      output_file
    ]

    stdout, stderr, status = Open3.capture3(*command)

    if status.success?
      Rails.logger.info("오디오 변환 성공: #{output_file}")
      output_file
    else
      Rails.logger.error("오디오 변환 실패: #{stderr}")
      nil
    end
  end

  # 오디오 파일 처리 (무음 제거 + 포맷 변환)
  def self.process_audio(input_file, output_format = "m4a")
    # 임시 파일 경로
    temp_file = "#{Dir.tmpdir}/temp_#{File.basename(input_file)}"
    output_file = "#{Dir.tmpdir}/processed_#{File.basename(input_file, '.*')}.#{output_format}"

    # 무음 구간 제거
    trimmed_file = trim_silence(input_file, temp_file)
    return nil unless trimmed_file

    # 포맷 변환
    converted_file = convert_audio(trimmed_file, output_format)

    # 임시 파일 삭제
    File.delete(temp_file) if File.exist?(temp_file)

    converted_file
  end
end
