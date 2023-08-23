use cairo_lib::hashing::hasher::Hasher;
use cairo_lib::utils::math::pow;
use cairo_lib::utils::types::bytes::Bytes;
use array::{ArrayTrait, SpanTrait};
use keccak::{keccak_u256s_le_inputs, cairo_keccak};
use traits::{Into, TryInto};
use option::OptionTrait;
use starknet::SyscallResultTrait;

#[derive(Drop)]
struct Keccak {}

#[generate_trait]
impl KeccakHasher of KeccakTrait {
    // @notice keccak256 hashes the input, matching Solidity keccak
    // @param input The input to hash, in big endian
    // @return The hash of the input, in little endian
    fn keccak_cairo(bytes: Bytes) -> u256 {
        let n = bytes.len();
        let q = n / 8;
        let r = n % 8;

        let mut keccak_input = ArrayTrait::new();
        let mut i: usize = 0;
        loop {
            if i >= q {
                break ();
            }

            let val = (*bytes.at(8 * i)).into()
                + (*bytes.at(8 * i + 1)).into() * 256
                + (*bytes.at(8 * i + 2)).into() * 65536
                + (*bytes.at(8 * i + 3)).into() * 16777216
                + (*bytes.at(8 * i + 4)).into() * 4294967296
                + (*bytes.at(8 * i + 5)).into() * 1099511627776
                + (*bytes.at(8 * i + 6)).into() * 281474976710656
                + (*bytes.at(8 * i + 7)).into() * 72057594037927936;

            keccak_input.append(val);

            i += 1;
        };

        let mut last_word: u64 = 0;
        let mut k: usize = 0;
        loop {
            if k >= r {
                break ();
            }

            let current: u64 = (*bytes.at(8 * q + k)).into();
            last_word += current * pow(256, k.into());

            k += 1;
        };

        cairo_keccak(ref keccak_input, last_word, r)
    }

    fn keccak_cairo_word64(words: Span<u64>) -> u256 {
        let n = words.len();

        let mut keccak_input = ArrayTrait::new();
        let mut i: usize = 0;
        if n > 1 {
            loop {
                if i >= n-1 {
                    break ();
                }
                keccak_input.append(*words.at(i));
                i += 1;
            };
        }

        let mut last = *words.at(n-1);
        let mut last_word_bytes = bytes_used(last);
        if last_word_bytes == 8 {
            keccak_input.append(last);
            last = 0;
            last_word_bytes = 0;
        }

        cairo_keccak(ref keccak_input, last, last_word_bytes)
    }
}

fn bytes_used(val: u64) -> usize {
    if val < 4294967296 { // 256^4
        if val < 65536 { // 256^2
            if val < 256 { // 256^1
                if val == 0 { return 0; } else { return 1; };
            }
            return 2;
        }
        if val < 16777216 { // 256^3
            return 3;
        }
        return 4;
    } else {
        if val < 281474976710656 { // 256^6
            if val < 1099511627776 { // 256^5
                return 5;
            }
            return 6;
        }
        if val < 72057594037927936 { // 256^7
            return 7;
        }
        return 8;
    }
}

impl KeccakHasherU256 of Hasher<u256, u256> {
    fn hash_single(a: u256) -> u256 {
        let mut arr = array![a];
        keccak_u256s_le_inputs(arr.span())
    }

    fn hash_double(a: u256, b: u256) -> u256 {
        let mut arr = array![a, b];
        keccak_u256s_le_inputs(arr.span())
    }

    fn hash_many(input: Span<u256>) -> u256 {
        keccak_u256s_le_inputs(input)
    }
}

impl KeccakHasherSpanU8 of Hasher<Span<u8>, u256> {
    fn hash_single(a: Span<u8>) -> u256 {
        let mut arr = ArrayTrait::new();
        let mut i: usize = 0;
        loop {
            if i >= a.len() {
                break arr.span();
            }
            let current = *a.at(i);
            arr.append(current.into());
            i += 1;
        };
        keccak_u256s_le_inputs(arr.span())
    }

    fn hash_double(a: Span<u8>, b: Span<u8>) -> u256 {
        let mut arr = ArrayTrait::new();
        let mut i: usize = 0;
        loop {
            if i >= a.len() {
                break arr.span();
            }
            let current = *a.at(i);
            arr.append(current.into());
            i += 1;
        };

        i = 0;
        loop {
            if i >= b.len() {
                break arr.span();
            }
            let current = *b.at(i);
            arr.append(current.into());
            i += 1;
        };
        keccak_u256s_le_inputs(arr.span())
    }

    fn hash_many(input: Span<Span<u8>>) -> u256 {
        let mut arr = ArrayTrait::new();
        let mut i: usize = 0;
        let mut j: usize = 0;
        loop {
            if i >= input.len() {
                break arr.span();
            }

            let current = *input.at(i);
            loop {
                if j >= current.len() {
                    break;
                }
                let current = *current.at(j);
                arr.append(current.into());
                j += 1;
            };
            i += 1;
        };

        keccak_u256s_le_inputs(arr.span())
    }
}

