"""MasterDnsVPN payload compression helpers."""

import zlib

try:
    import zstandard as zstd

    ZSTD_AVAILABLE = True
except ImportError:
    ZSTD_AVAILABLE = False

try:
    import lz4.block as lz4block

    LZ4_AVAILABLE = True
except ImportError:
    LZ4_AVAILABLE = False


class Compression_Type:
    OFF = 0
    ZSTD = 1
    LZ4 = 2
    ZLIB = 3


SUPPORTED_COMPRESSION_TYPES = (
    Compression_Type.OFF,
    Compression_Type.ZSTD,
    Compression_Type.LZ4,
    Compression_Type.ZLIB,
)

_COMPRESSION_NAME = {
    Compression_Type.OFF: "OFF",
    Compression_Type.ZSTD: "ZSTD",
    Compression_Type.LZ4: "LZ4",
    Compression_Type.ZLIB: "ZLIB",
}


def normalize_compression_type(compression_type: int) -> int:
    ctype = int(compression_type or 0)
    if ctype in SUPPORTED_COMPRESSION_TYPES:
        return ctype
    return Compression_Type.OFF


def get_compression_name(compression_type: int) -> str:
    return _COMPRESSION_NAME.get(compression_type, "UNKNOWN")


def compress_payload(
    data: bytes, comp_type: int, min_size: int = 100
) -> tuple[bytes, int]:
    """
    Compresses data if it's larger than min_size.
    Returns (processed_data, actual_compression_type_used).
    """
    if not data or len(data) <= min_size or comp_type == Compression_Type.OFF:
        return data, Compression_Type.OFF

    try:
        if comp_type == Compression_Type.ZLIB:
            comp_obj = zlib.compressobj(level=1, wbits=-15)
            comp_data = comp_obj.compress(data) + comp_obj.flush()
        elif comp_type == Compression_Type.ZSTD and ZSTD_AVAILABLE:
            comp_data = zstd.ZstdCompressor(level=1).compress(data)
        elif comp_type == Compression_Type.LZ4 and LZ4_AVAILABLE:
            comp_data = lz4block.compress(data, store_size=True)
        else:
            return data, Compression_Type.OFF

        # Only use compressed data if it actually saved space.
        if len(comp_data) < len(data):
            return comp_data, comp_type
    except Exception:
        pass

    return data, Compression_Type.OFF


def is_compression_type_available(comp_type: int) -> bool:
    if comp_type == Compression_Type.ZLIB:
        return True
    elif comp_type == Compression_Type.ZSTD:
        return ZSTD_AVAILABLE
    elif comp_type == Compression_Type.LZ4:
        return LZ4_AVAILABLE
    return False


def decompress_payload(data: bytes, comp_type: int) -> bytes:
    """Decompresses payload based on the compression type used."""
    if not data or comp_type == Compression_Type.OFF:
        return data

    try:
        if comp_type == Compression_Type.ZLIB:
            return zlib.decompressobj(wbits=-15).decompress(data)
        elif comp_type == Compression_Type.ZSTD and ZSTD_AVAILABLE:
            return zstd.ZstdDecompressor().decompress(data)
        elif comp_type == Compression_Type.LZ4 and LZ4_AVAILABLE:
            return lz4block.decompress(data)
    except Exception:
        pass

    return data
