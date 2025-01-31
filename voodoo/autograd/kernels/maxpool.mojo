from algorithm import vectorize
from math import max

from voodoo.autograd import Node
from voodoo.constants import PREFETCH_READ, PREFETCH_WRITE, F32_MAX, NELTS


trait MaxPool:
    ...


@register_passable("trivial")
struct MaxPool1D(MaxPool):
    @staticmethod
    fn fw(c: Node, a: Node):
        let params = c.get_other_params()

        let kernel_width = params[0]
        let stride = params[1]
        let padding = params[2]

        let batches = a.get_shape()[0]
        let channels = a.get_shape()[1]
        let input_width = a.get_shape()[2]

        let output_width = c.get_shape()[2]

        DTypePointer.prefetch[PREFETCH_READ](a.get_data())
        DTypePointer.prefetch[PREFETCH_WRITE](c.get_data())

        for batch in range(batches):
            let batch_offset = batch * channels * input_width
            let output_batch_offset = batch * channels * output_width
            for channel in range(channels):
                let channel_offset = channel * input_width
                let output_channel_offset = channel * output_width
                for output_pos in range(output_width):
                    let input_pos = output_pos * stride - padding
                    var max_value = -F32_MAX

                    @parameter
                    fn fw_vec[NELTS: Int](kernel_pos: Int):
                        let input_index = channel_offset + input_pos + kernel_pos
                        if input_index >= 0 and input_index < input_width:
                            let value = a.get_data().simd_load[NELTS](
                                batch_offset + input_index
                            )
                            max_value = max(max_value, value.reduce_max())

                    vectorize[NELTS, fw_vec](kernel_width)
                    c.get_data().store(
                        output_batch_offset + output_channel_offset + output_pos,
                        max_value,
                    )

    @staticmethod
    fn bw(c: Node, a: Node):
        let params = c.get_other_params()

        let kernel_width = params[0]
        let stride = params[1]
        let padding = params[2]

        let batches = a.get_shape()[0]
        let channels = a.get_shape()[1]
        let input_width = a.get_shape()[2]

        let output_width = c.get_shape()[2]

        DTypePointer.prefetch[PREFETCH_READ](a.get_data())
        DTypePointer.prefetch[PREFETCH_READ](c.get_data())
        DTypePointer.prefetch[PREFETCH_READ](c.get_grad())
        DTypePointer.prefetch[PREFETCH_WRITE](a.get_grad())

        for batch in range(batches):
            let batch_offset = batch * channels * input_width
            let output_batch_offset = batch * channels * output_width
            for channel in range(channels):
                let channel_offset = channel * input_width
                let output_channel_offset = channel * output_width
                for output_pos in range(output_width):
                    let input_pos = output_pos * stride - padding
                    let output_index = output_batch_offset + output_channel_offset + output_pos
                    let max_value = c.get_data()[output_index]

                    @parameter
                    fn bw_vec[NELTS: Int](kernel_pos: Int):
                        let input_index = channel_offset + input_pos + kernel_pos
                        if input_index >= 0 and input_index < input_width:
                            let value = a.get_data().simd_load[NELTS](
                                batch_offset + input_index
                            )
                            let grad = c.get_grad().simd_load[NELTS](output_index)
                            let grad_value = (value == max_value).select(grad, 0)
                            a.get_grad().simd_store[NELTS](
                                batch_offset + input_index, grad_value
                            )

                    vectorize[NELTS, bw_vec](kernel_width)

                    let grad = c.get_grad()[output_index]
                    a.get_grad().store(batch_offset + input_pos, grad.reduce_add())


@register_passable("trivial")
struct MaxPool2D(MaxPool):
    @staticmethod
    fn fw(c: Node, a: Node):
        let params = c.get_other_params()

        let kernel_width = params[0]
        let kernel_height = params[1]
        let stride = params[2]
        let padding = params[3]

        let batches = a.get_shape()[0]
        let channels = a.get_shape()[1]
        let input_height = a.get_shape()[2]
        let input_width = a.get_shape()[3]

        let output_height = c.get_shape()[2]
        let output_width = c.get_shape()[3]

        DTypePointer.prefetch[PREFETCH_READ](a.get_data())
        DTypePointer.prefetch[PREFETCH_WRITE](c.get_data())

        for batch in range(batches):
            let batch_offset = batch * channels * input_height * input_width
            let output_batch_offset = batch * channels * output_height * output_width
            for channel in range(channels):
                let channel_offset = channel * input_height * input_width
                let output_channel_offset = channel * output_height * output_width
                for output_y in range(output_height):
                    let input_y = output_y * stride - padding
                    for output_x in range(output_width):
                        let input_x = output_x * stride - padding
                        var max_value = -F32_MAX

                        for kernel_y in range(kernel_height):

                            @parameter
                            fn fw_vec[NELTS: Int](kernel_x: Int):
                                let input_index = channel_offset + input_y + kernel_y * input_width + input_x + kernel_x
                                if (
                                    input_index >= 0
                                    and input_index < input_height * input_width
                                ):
                                    let value = a.get_data().simd_load[NELTS](
                                        batch_offset + input_index
                                    )
                                    max_value = max(max_value, value.reduce_max())

                            vectorize[NELTS, fw_vec](kernel_width)
                        c.get_data().store(
                            output_batch_offset
                            + output_channel_offset
                            + output_y * output_width
                            + output_x,
                            max_value,
                        )

    @staticmethod
    fn bw(c: Node, a: Node):
        let params = c.get_other_params()

        let kernel_width = params[0]
        let kernel_height = params[1]
        let stride = params[2]
        let padding = params[3]

        let batches = a.get_shape()[0]
        let channels = a.get_shape()[1]
        let input_height = a.get_shape()[2]
        let input_width = a.get_shape()[3]

        let output_height = c.get_shape()[2]
        let output_width = c.get_shape()[3]

        DTypePointer.prefetch[PREFETCH_READ](a.get_data())
        DTypePointer.prefetch[PREFETCH_READ](c.get_data())
        DTypePointer.prefetch[PREFETCH_READ](c.get_grad())
        DTypePointer.prefetch[PREFETCH_WRITE](a.get_grad())

        for batch in range(batches):
            let batch_offset = batch * channels * input_height * input_width
            let output_batch_offset = batch * channels * output_height * output_width
            for channel in range(channels):
                let channel_offset = channel * input_height * input_width
                let output_channel_offset = channel * output_height * output_width
                for output_y in range(output_height):
                    let input_y = output_y * stride - padding
                    for output_x in range(output_width):
                        let input_x = output_x * stride - padding
                        let output_index = (
                            output_batch_offset
                            + output_channel_offset
                            + output_y * output_width
                            + output_x
                        )
                        let max_value = c.get_data()[output_index]

                        for kernel_y in range(kernel_height):

                            @parameter
                            fn bw_vec[NELTS: Int](kernel_x: Int):
                                let input_index = channel_offset + input_y + kernel_y * input_width + input_x + kernel_x
                                if (
                                    input_index >= 0
                                    and input_index < input_height * input_width
                                ):
                                    let value = a.get_data().simd_load[NELTS](
                                        batch_offset + input_index
                                    )
                                    let grad = c.get_grad().simd_load[NELTS](
                                        output_index
                                    )
                                    let grad_value = (value == max_value).select(
                                        grad, 0
                                    )
                                    a.get_grad().simd_store[NELTS](
                                        batch_offset + input_index, grad_value
                                    )

                            vectorize[NELTS, bw_vec](kernel_width)

                        let grad = c.get_grad()[output_index]
                        a.get_grad().store(
                            batch_offset + input_y * input_width + input_x,
                            grad.reduce_add(),
                        )
