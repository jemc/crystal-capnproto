require "./spec_helper"

def bytes(array : Array(UInt8))
  Bytes.new(array.size) { |i| array[i] }
end

describe CapnProto::Segment do
  it "reads an odd number of segments, all at once (from a complete stream)" do
    stream = IO::Memory.new
    stream.write(bytes([2, 0, 0, 0] of UInt8)) # there will be 3 segments
    stream.write(bytes([3, 0, 0, 0] of UInt8)) # the first will be 3 words long
    stream.write(bytes([4, 0, 0, 0] of UInt8)) # the second will be 4 words long
    stream.write(bytes([5, 0, 0, 0] of UInt8)) # the last will be 5 words long
    stream.write(bytes([
      0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
      0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22,
      0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
      0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
      0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55,
      0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
      0x77, 0x77, 0x77, 0x77, 0x77, 0x77, 0x77, 0x77,
      0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88,
      0x99, 0x99, 0x99, 0x99, 0x99, 0x99, 0x99, 0x99,
      0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa,
      0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb,
      0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc,
    ] of UInt8)) # the segments themselves
    stream.write(bytes([
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
    ] of UInt8)) # additional data that isn't actually part of the segments
    stream.rewind

    reader = CapnProto::Segment::Reader.new
    segments = reader.read(stream).not_nil!
    segments.size.should eq 3

    segments[0].bytes.should eq bytes([
      0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
      0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22,
      0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
    ] of UInt8)

    segments[1].bytes.should eq bytes([
      0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
      0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55,
      0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
      0x77, 0x77, 0x77, 0x77, 0x77, 0x77, 0x77, 0x77,
    ] of UInt8)

    segments[2].bytes.should eq bytes([
      0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88,
      0x99, 0x99, 0x99, 0x99, 0x99, 0x99, 0x99, 0x99,
      0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa,
      0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb,
      0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc,
    ] of UInt8)

    # The junk data at the end of the stream was not read by the reader.
    final_junk_data = Bytes.new(16)
    stream.read(final_junk_data).should eq 16
    final_junk_data.should eq bytes([
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
    ] of UInt8)
  end

  it "reads an even number of segments, from a frequently interrupted stream" do
    stream = IO::Memory.new
    reader = CapnProto::Segment::Reader.new

    # There will be 2 segments, but we will write just one byte first,
    # which isn't enough to read the full segment count indicator yet.
    stream.write(bytes([1] of UInt8))
    stream.seek(-1, IO::Seek::Current)
    segments = reader.read(stream).should eq nil

    # Now we'll write the rest of the bytes needed to know the segment count,
    # but it's not enough yet to read the full header.
    stream.write(bytes([0, 0, 0] of UInt8))
    stream.seek(-3, IO::Seek::Current)
    segments = reader.read(stream).should eq nil

    # The first segment will be 3 words long.
    # But this isn't the full header yet.
    stream.write(bytes([3, 0, 0, 0] of UInt8))
    stream.seek(-4, IO::Seek::Current)
    segments = reader.read(stream).should eq nil

    # The second segment will be 5 words long.
    # We also include the header padding here (because the count is even).
    # This concludes the full header length.
    stream.write(bytes([5, 0, 0, 0, 0, 0, 0, 0] of UInt8))
    stream.seek(-8, IO::Seek::Current)
    segments = reader.read(stream).should eq nil

    # Now we write part of (but not all of) the first segment.
    # It won't be ready to read yet.
    stream.write(bytes([
      0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
      0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22,
    ] of UInt8))
    stream.seek(-16, IO::Seek::Current)
    segments = reader.read(stream).should eq nil

    # Now we write the rest of the first segment and part of the second one.
    # Only the first segment will be ready to read.
    stream.write(bytes([
      0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
      0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
      0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55,
      0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
    ] of UInt8))
    stream.seek(-32, IO::Seek::Current)
    segments = reader.read(stream).should eq nil

    # Now we write the rest of the second segment as well as some junk data.
    # This chunk will let the reader finish reading the segment table.
    stream.write(bytes([
      0x77, 0x77, 0x77, 0x77, 0x77, 0x77, 0x77, 0x77,
      0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88,
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
    ] of UInt8))
    stream.seek(-32, IO::Seek::Current)
    segments = reader.read(stream).not_nil!

    segments.size.should eq 2

    segments[0].bytes.should eq bytes([
      0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
      0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22,
      0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
    ] of UInt8)

    segments[1].bytes.should eq bytes([
      0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
      0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55,
      0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
      0x77, 0x77, 0x77, 0x77, 0x77, 0x77, 0x77, 0x77,
      0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88,
    ] of UInt8)

    # The junk data at the end of the stream was not read by the reader.
    final_junk_data = Bytes.new(16)
    stream.read(final_junk_data).should eq 16
    final_junk_data.should eq bytes([
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
      0xde, 0xad, 0xbe, 0xef, 0xde, 0xad, 0xbe, 0xef,
    ] of UInt8)
  end

  it "refuses to read a header whose segment count is too large" do
    stream = IO::Memory.new

    # There will be 0x1000000 segments, which will exceed our 64 MiB budget
    # just to read the header data alone (let alone the segments themselves).
    stream.write(bytes([0xff, 0xff, 0xff, 0x00] of UInt8))
    stream.rewind

    reader = CapnProto::Segment::Reader.new
    expect_raises(ArgumentError, /exceeds max total size/) do
      reader.read(stream)
    end
  end

  it "refuses to read a header announcing segments that are too large" do
    stream = IO::Memory.new

    # There will be 4 segments, each of which will be 0x1000000 bytes
    # (that is, 0x200000 words), which exactly matches our 64 MiB budget
    # but will exceed it if you count the header data toward the budget too.
    stream.write(bytes([
      0x03, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x20, 0x00,
      0x00, 0x00, 0x20, 0x00,
      0x00, 0x00, 0x20, 0x00,
      0x00, 0x00, 0x20, 0x00,
      0x00, 0x00, 0x00, 0x00,
    ] of UInt8))
    stream.rewind

    reader = CapnProto::Segment::Reader.new
    expect_raises(ArgumentError, /exceeds max total size/) do
      reader.read(stream)
    end
  end
end
