from algorithm import vectorize
from math import max, min
from voodoo import Node
from voodoo.utils import (
    recursive_broadcast,
    recursive_broadcast_bw,
)
from ..constants import PREFETCH_READ, PREFETCH_WRITE, F32_MAX, NELTS


struct MMul:
    @parameter
    @staticmethod
    @always_inline
    fn base_case_depth(depth: Int, a: Node, b: Node) -> Bool:
        return depth == max(a.num_dims, b.num_dims) - 2

    @staticmethod
    fn fw(c: Node, a: Node, b: Node):
        recursive_broadcast[Self.kernel_mmul_fw, Self.base_case_depth](c, a, b)

    @staticmethod
    fn bw(c: Node, a: Node, b: Node):
        if not a.is_single_ptr.load():
            recursive_broadcast_bw[Self.kernel_mmul_bw_a, Self.base_case_depth](c, a, b)
        if not b.is_single_ptr.load():
            recursive_broadcast_bw[Self.kernel_mmul_bw_b, Self.base_case_depth](c, a, b)

    @parameter
    @staticmethod
    fn kernel_mmul_fw(
        c: Node, a: Node, b: Node, a_index: Int, b_index: Int, c_index: Int, depth: Int
    ) -> None:
        let M = a.shape.load(a.num_dims - 2)
        let K = b.shape.load(b.num_dims - 2)
        let N = c.shape.load(c.num_dims - 1)

        let offset_a = a_index * M * a.shape.load(a.num_dims - 1)
        let offset_b = b_index * K * b.shape.load(b.num_dims - 1)
        let offset_c = c_index * N * N

        let a_data = a.data.load(0)
        let b_data = b.data.load(0)
        let c_data = c.data.load(0)

        DTypePointer.prefetch[PREFETCH_READ](a_data)
        DTypePointer.prefetch[PREFETCH_READ](b_data)
        DTypePointer.prefetch[PREFETCH_READ](c_data)
        DTypePointer.prefetch[PREFETCH_WRITE](c_data)

        for m in range(0, M, 4):
            let start_offset_c = offset_c + m * N
            let start_offset_c_2 = start_offset_c + N
            let start_offset_c_3 = start_offset_c_2 + N
            let start_offset_c_4 = start_offset_c_3 + N
            let start_offset_a = offset_a + m * K
            let start_offset_a_2 = start_offset_a + K
            let start_offset_a_3 = start_offset_a_2 + K
            let start_offset_a_4 = start_offset_a_3 + K
            for kb in range(0, K, NELTS):
                for k in range(kb, min(kb + NELTS, K)):
                    let b_off = offset_b + k * N

                    @parameter
                    @always_inline
                    fn dot_fw[NELTS: Int](n: Int):
                        let b_data_n = b_data.simd_load[NELTS](b_off + n)

                        @parameter
                        @always_inline
                        fn dot_store(c_off_n: Int, a_off: Int):
                            c_data.simd_store[NELTS](
                                c_off_n,
                                b_data_n.fma(
                                    a_data.load(a_off + k),
                                    c_data.simd_load[NELTS](c_off_n),
                                ),
                            )

                        dot_store(start_offset_c + n, start_offset_a)
                        dot_store(start_offset_c_2 + n, start_offset_a_2)
                        dot_store(start_offset_c_3 + n, start_offset_a_3)
                        dot_store(start_offset_c_4 + n, start_offset_a_4)

                    vectorize[NELTS, dot_fw](N)

    @parameter
    @staticmethod
    fn kernel_mmul_bw_a(
        c: Node, a: Node, b: Node, a_index: Int, b_index: Int, c_index: Int, depth: Int
    ) -> None:
        let M = a.shape.load(a.num_dims - 2)
        let K = b.shape.load(b.num_dims - 2)
        let N = c.shape.load(c.num_dims - 1)

        let offset_a = a_index * M * a.shape.load(a.num_dims - 1)
        let offset_b = b_index * K * b.shape.load(b.num_dims - 1)
        let offset_c = c_index * N * N

        let a_grad = a.data.load(1)
        let b_data = b.data.load(0)
        let c_grad = c.data.load(1)

        DTypePointer.prefetch[PREFETCH_READ](a_grad)
        DTypePointer.prefetch[PREFETCH_WRITE](a_grad)
        DTypePointer.prefetch[PREFETCH_READ](b_data)
        DTypePointer.prefetch[PREFETCH_READ](c_grad)

        for m in range(0, M, 2):
            let _offset_c = offset_c + m * N
            let _offset_c_1 = offset_c + (m + 1) * N
            let start_offset_a = offset_a + m * K
            let start_offset_a_2 = start_offset_a + K
            for nb in range(0, N, NELTS):
                for n in range(nb, min(nb + NELTS, N), 2):
                    let c_grad_0 = c_grad.load(_offset_c + n)
                    let c_grad_1 = c_grad.load(_offset_c_1 + n)

                    @parameter
                    @always_inline
                    fn dot_bw[NELTS: Int](k: Int):
                        @parameter
                        @always_inline
                        fn dot_store(a_off: Int, b_off: Int, scalar: Float32):
                            a_grad.simd_store[NELTS](
                                a_off,
                                b_data.simd_load[NELTS](b_off).fma(
                                    scalar,
                                    a_grad.simd_load[NELTS](a_off),
                                ),
                            )

                        let start_offset_b = offset_b + k * N + n

                        dot_store(start_offset_a + k, start_offset_b, c_grad_0)
                        dot_store(start_offset_a_2 + k, start_offset_b, c_grad_1)

                    vectorize[NELTS, dot_bw](K)

    @parameter
    @staticmethod
    fn kernel_mmul_bw_b(
        c: Node, a: Node, b: Node, a_index: Int, b_index: Int, c_index: Int, depth: Int
    ) -> None:
        let M = a.shape.load(a.num_dims - 2)
        let K = b.shape.load(b.num_dims - 2)
        let N = c.shape.load(c.num_dims - 1)

        let offset_a = a_index * M * a.shape.load(a.num_dims - 1)
        let offset_b = b_index * K * b.shape.load(b.num_dims - 1)
        let offset_c = c_index * N * N

        let a_data = a.data.load(0)
        let b_grad = b.data.load(1)
        let c_grad = c.data.load(1)

        DTypePointer.prefetch[PREFETCH_READ](a_data)
        DTypePointer.prefetch[PREFETCH_READ](b_grad)
        DTypePointer.prefetch[PREFETCH_WRITE](b_grad)
        DTypePointer.prefetch[PREFETCH_READ](c_grad)

        for k in range(K):
            let _a_off = offset_a + k
            let _b_off = offset_b + k * N

            for m in range(M):
                let a_data = a_data.load(_a_off + m * K)
                let _c_off = offset_c + m * N

                @parameter
                @always_inline
                fn dot_bw[NELTS: Int](n: Int):
                    let b_off = _b_off + n

                    b.store_grad[NELTS](
                        b_off,
                        c_grad.simd_load[NELTS](_c_off + n).fma(
                            a_data,
                            b_grad.simd_load[NELTS](b_off),
                        ),
                    )

                vectorize[NELTS, dot_bw](N)
