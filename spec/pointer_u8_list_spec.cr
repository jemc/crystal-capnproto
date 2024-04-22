require "./spec_helper"

from_segment = ->(byte_offset : UInt32, bytes : Bytes) do
  segments = [] of CapnProto::Segment
  segment = CapnProto::Segment.new(segments, bytes)
  CapnProto::Pointer::U8List.parse_from(
    segment, byte_offset, segment.u64(byte_offset)
  )
end

from_segments = ->(byte_offset : UInt32, chunks : Array(Bytes)) do
  segments = [] of CapnProto::Segment
  chunks.each { |chunk| CapnProto::Segment.new(segments, chunk) }
  segment = segments[0]
  CapnProto::Pointer::U8List.parse_from(
    segment, byte_offset, segment.u64(byte_offset)
  )
end

describe CapnProto::Pointer::U8List do
  it "reads text from a byte region" do
    pointer = from_segment.call(0_u32, Bytes[
      0x01, 0x00, 0x00, 0x00, 0x02, 0x01, 0x00, 0x00,
      'H'.ord, 'e'.ord, 'r'.ord, 'e'.ord, '\''.ord, 's'.ord, ' '.ord,
      's'.ord, 'o'.ord, 'm'.ord, 'e'.ord, ' '.ord,
      't'.ord, 'e'.ord, 'x'.ord, 't'.ord, ' '.ord,
      'w'.ord, 'i'.ord, 't'.ord, 'h'.ord, ' '.ord,
      'l'.ord, 'e'.ord, 'n'.ord, 'g'.ord, 't'.ord, 'h'.ord, ' '.ord,
      '3'.ord, '1'.ord, 0x00,
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
    ])

    pointer.to_s.should eq "Here's some text with length 31"
  end

  it "can point to a prior byte region" do
    pointer = from_segment.call(0x20_u32, Bytes[
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
      'H'.ord, 'e'.ord, 'r'.ord, 'e'.ord, ' '.ord,
      'i'.ord, 's'.ord, ' '.ord, 'a'.ord, ' '.ord,
      't'.ord, 'e'.ord, 'x'.ord, 't'.ord, '!'.ord, 0x00,
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
      0xf1, 0xff, 0xff, 0xff, 0x82, 0x00, 0x00, 0x00,
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
    ])

    pointer.to_s.should eq "Here is a text!"
  end

  it "can point to a byte region via a far pointer" do
    pointer = from_segments.call(0_u32, [
      Bytes[
        0x12, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
      ],
      Bytes[
        'T'.ord, 'h'.ord, 'e'.ord, 'r'.ord, 'e'.ord, '\''.ord, 's'.ord, ' '.ord,
        'n'.ord, 'o'.ord, 't'.ord, 'h'.ord, 'i'.ord, 'n'.ord, 'g'.ord, ' '.ord,
        'm'.ord, 'e'.ord, 'a'.ord, 'n'.ord, 'i'.ord, 'n'.ord, 'g'.ord,
        'f'.ord, 'u'.ord, 'l'.ord, ' '.ord, 'i'.ord, 'n'.ord, ' '.ord,
        't'.ord, 'h'.ord, 'i'.ord, 's'.ord, ' '.ord,
        'm'.ord, 'i'.ord, 'd'.ord, 'd'.ord, 'l'.ord, 'e'.ord, ' '.ord,
        's'.ord, 'e'.ord, 'g'.ord, 'm'.ord, 'e'.ord, 'n'.ord, 't'.ord, '.'.ord,
        ' '.ord, 'I'.ord, 't'.ord, '\''.ord, 's'.ord, ' '.ord,
        'j'.ord, 'u'.ord, 's'.ord, 't'.ord, ' '.ord, 'a'.ord, ' '.ord,
        'p'.ord, 'l'.ord, 'a'.ord, 'c'.ord, 'e'.ord,
        'h'.ord, 'o'.ord, 'l'.ord, 'd'.ord, 'e'.ord, 'r'.ord, ' '.ord,
        'i'.ord, 'n'.ord, ' '.ord, 'b'.ord, 'e'.ord, 't'.ord, 'w'.ord,
        'e'.ord, 'e'.ord, 'n'.ord, ' '.ord, 't'.ord, 'h'.ord, 'e'.ord, ' '.ord,
        'o'.ord, 't'.ord, 'h'.ord, 'e'.ord, 'r'.ord, ' '.ord,
        't'.ord, 'w'.ord, 'o'.ord, '.'.ord,
      ],
      Bytes[
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
        0x01, 0x00, 0x00, 0x00, 0x02, 0x01, 0x00, 0x00,
        'H'.ord, 'e'.ord, 'r'.ord, 'e'.ord, '\''.ord, 's'.ord, ' '.ord,
        's'.ord, 'o'.ord, 'm'.ord, 'e'.ord, ' '.ord,
        't'.ord, 'e'.ord, 'x'.ord, 't'.ord, ' '.ord,
        'w'.ord, 'i'.ord, 't'.ord, 'h'.ord, ' '.ord,
        'l'.ord, 'e'.ord, 'n'.ord, 'g'.ord, 't'.ord, 'h'.ord, ' '.ord,
        '3'.ord, '1'.ord, 0x00,
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
      ]
    ])

    pointer.to_s.should eq "Here's some text with length 31"
  end

  it "can point to a byte region via a double-far pointer" do
    pointer = from_segments.call(0_u32, [
      Bytes[
        0x26, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
      ],
      Bytes[
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
        0x12, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x00, 0x00, 0x02, 0x01, 0x00, 0x00,
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
      ],
      Bytes[
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
        'H'.ord, 'e'.ord, 'r'.ord, 'e'.ord, '\''.ord, 's'.ord, ' '.ord,
        's'.ord, 'o'.ord, 'm'.ord, 'e'.ord, ' '.ord,
        't'.ord, 'e'.ord, 'x'.ord, 't'.ord, ' '.ord,
        'w'.ord, 'i'.ord, 't'.ord, 'h'.ord, ' '.ord,
        'l'.ord, 'e'.ord, 'n'.ord, 'g'.ord, 't'.ord, 'h'.ord, ' '.ord,
        '3'.ord, '1'.ord, 0x00,
        0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
      ]
    ])

    pointer.to_s.should eq "Here's some text with length 31"
  end
end
