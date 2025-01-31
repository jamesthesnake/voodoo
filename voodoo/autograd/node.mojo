from math import sin, cos, sqrt, log, iota
from random import rand, seed
from memory import memset
from algorithm import sum

from voodoo.utils import Vector, warn


@register_passable("trivial")
struct Node:
    var _id_ptr: Pointer[Int]
    var _data_id_ptr: Pointer[Int]
    var _grad_id_ptr: Pointer[Int]
    var _data_ptr: Pointer[DTypePointer[DType.float32]]
    var _parents: Vector[Int]
    var _children: Vector[Int]
    var _dependencies_ptr: Pointer[Int]  # Has to be a pointer
    var _is_static: Bool
    var _computed_ptr: Pointer[Bool]  # Has to be a pointer
    var _grad_computed_ptr: Pointer[Bool]  # Has to be a pointer
    var _operator_id: Int
    var _tmp_visited: Bool
    var _checkpoint: Bool
    var _is_single: Bool
    var _cap: Int
    var _num_dims: Int
    var _shape: Vector[Int]
    var _strides: Vector[Int]
    var _other_params: Vector[Int]

    fn __init__(
        id: Int,
        shape: Vector[Int],
        is_static: Bool = True,
        other_params: Vector[Int] = Vector[Int](),
        checkpoint: Bool = False,
        operator_id: Int = -1,
        is_single: Bool = False,
    ) raises -> Self:
        let id_ptr = Pointer[Int].alloc(1)
        id_ptr.store(id)
        let data_id_ptr = Pointer[Int].alloc(1)
        data_id_ptr.store(-1)
        let grad_id_ptr = Pointer[Int].alloc(1)
        grad_id_ptr.store(-1)
        let data_ptr = Pointer[DTypePointer[DType.float32]].alloc(2)
        let data = DTypePointer[DType.float32].get_null()
        let grad = DTypePointer[DType.float32].get_null()
        data_ptr.store(0, data)
        data_ptr.store(1, grad)
        let parents = Vector[Int]()
        let children = Vector[Int]()
        let dependencies_ptr = Pointer[Int].alloc(1)
        dependencies_ptr.store(0)
        let computed_ptr = Pointer[Bool].alloc(1)
        computed_ptr.store(is_static)
        let grad_computed_ptr = Pointer[Bool].alloc(1)
        grad_computed_ptr.store(False)

        var cap = 1
        for i in range(len(shape)):
            cap *= shape[i]

        let strides = Vector[Int](len(shape))
        strides[len(shape) - 1] = 1
        for i in range(len(shape) - 1):
            strides[len(shape) - i - 2] = (
                strides[len(shape) - i - 1] * shape[len(shape) - i - 1]
            )

        return Node {
            _id_ptr: id_ptr,
            _data_id_ptr: data_id_ptr,
            _grad_id_ptr: grad_id_ptr,
            _data_ptr: data_ptr,
            _parents: parents,
            _children: children,
            _dependencies_ptr: dependencies_ptr,
            _is_static: is_static,
            _computed_ptr: computed_ptr,
            _grad_computed_ptr: grad_computed_ptr,
            _operator_id: operator_id,
            _tmp_visited: False,
            _checkpoint: checkpoint,
            _is_single: is_single,
            _cap: cap,
            _num_dims: len(shape),
            _shape: shape,
            _strides: strides,
            _other_params: other_params,
        }

    fn get_id(self) -> Int:
        return self._id_ptr.load()

    fn set_id(self, id: Int):
        self._id_ptr.store(id)

    fn get_data_id(self) -> Int:
        return self._data_id_ptr.load()

    fn set_data_id(self, id: Int):
        self._data_id_ptr.store(id)

    fn get_grad_id(self) -> Int:
        return self._grad_id_ptr.load()

    fn set_grad_id(self, id: Int):
        self._grad_id_ptr.store(id)

    fn get_data(self) -> DTypePointer[DType.float32]:
        return self._data_ptr[0]

    fn set_data(self, data: DTypePointer[DType.float32]):
        self._data_ptr.store(0, data)

    fn get_grad(self) -> DTypePointer[DType.float32]:
        return self._data_ptr[1]

    fn set_grad(self, grad: DTypePointer[DType.float32]):
        self._data_ptr.store(1, grad)

    fn get_parents(self) -> Vector[Int]:
        return self._parents

    fn push_back_parent(inout self, parent: Int):
        self._parents.push_back(parent)

    fn clear_parents(inout self):
        self._parents.clear()

    fn get_children(self) -> Vector[Int]:
        return self._children

    fn push_back_child(inout self, child: Int):
        self._children.push_back(child)

    fn clear_children(inout self):
        self._children.clear()

    fn get_dependencies(self) -> Int:
        return self._dependencies_ptr.load()

    fn set_dependencies(self, dependencies: Int):
        self._dependencies_ptr.store(dependencies)

    fn get_is_static(self) -> Bool:
        return self._is_static

    fn set_is_static(inout self, is_static: Bool):
        self._is_static = is_static

    fn get_computed(self) -> Bool:
        return self._computed_ptr.load()

    fn set_computed(self, computed: Bool):
        self._computed_ptr.store(computed)

    fn get_grad_computed(self) -> Bool:
        return self._grad_computed_ptr.load()

    fn set_grad_computed(self, grad_computed: Bool):
        self._grad_computed_ptr.store(grad_computed)

    fn get_operator_id(self) -> Int:
        return self._operator_id

    fn set_operator_id(inout self, operator_id: Int):
        self._operator_id = operator_id

    fn get_grad_operator_id(self) -> Int:
        return self._operator_id + 1

    fn get_tmp_visited(self) -> Bool:
        return self._tmp_visited

    fn set_tmp_visited(inout self, tmp_visited: Bool):
        self._tmp_visited = tmp_visited

    fn get_checkpoint(self) -> Bool:
        return self._checkpoint

    fn set_checkpoint(inout self, checkpoint: Bool):
        self._checkpoint = checkpoint

    fn get_is_single(self) -> Bool:
        return self._is_single

    fn set_is_single(inout self, is_single: Bool):
        self._is_single = is_single

    fn get_cap(self) -> Int:
        return self._cap

    fn get_num_dims(self) -> Int:
        return self._num_dims

    fn get_shape(self) -> Vector[Int]:
        return self._shape

    fn get_strides(self) -> Vector[Int]:
        return self._strides

    fn get_other_params(self) -> Vector[Int]:
        return self._other_params

    fn is_zero(self) -> Bool:
        return sum[1, DType.float32, AddressSpace.GENERIC](self._data_ptr[0]) == 0.0

    fn fill(self, val: Float32):
        for i in range(self._cap):
            self._data_ptr[0].store(i, val)

    fn fill_incr(self):
        iota(self._data_ptr[0], self._cap)

    fn fill_grad(self, val: Float32):
        for i in range(self._cap):
            self._data_ptr[1].store(i, val)

    fn grad_fill_incr(self):
        iota(self._data_ptr[1], self._cap)

    fn free(self):
        self._id_ptr.free()
        self._data_id_ptr.free()
        self._grad_id_ptr.free()
        self._data_ptr[0].free()
        self._data_ptr[1].free()
        self._data_ptr.free()
        self._parents.free()
        self._children.free()
        self._dependencies_ptr.free()
        self._computed_ptr.free()
        self._grad_computed_ptr.free()
        self._shape.free()
        self._strides.free()
        self._other_params.free()

    fn print(self, accuracy: Int = 6) raises:
        let row: Int = self._shape[self._num_dims - 2]
        let cols: Int = self._shape[self._num_dims - 1]
        let col_strides: Int = (self._strides[0] * self._shape[0]) // cols
        print(" ")
        var times = 1
        if self._grad_computed_ptr.load() and self._grad_id_ptr.load() != -1:
            times = 2
        print_no_newline("<Tensor: ")
        for i in range(col_strides):
            if col_strides > 10 and i > 4 and i < col_strides - 5:
                if i == 5:
                    print("                 ... ")
                continue
            else:
                if i > 0:
                    print_no_newline("           ")
                else:
                    print_no_newline("[ ")

                var indent = 0
                for d in range(self._num_dims - 1):
                    if cols * i % self._strides[d] == 0:
                        print_no_newline("[ ")
                        indent += 1
                    else:
                        print_no_newline("  ")

                for j in range(cols):
                    if cols > 10 and j >= 3 and j < cols - 3:
                        if j == 3:
                            print_no_newline("... , ")
                        continue
                    else:
                        let idx = cols * i + j
                        print_no_newline(
                            String(self._data_ptr[0][idx])[:accuracy] if self._data_ptr[
                                0
                            ][idx]
                            != 0.0 else String(0.000)[:accuracy]
                        )
                        if j != cols - 1:
                            print_no_newline(", ")

                for d in range(self._num_dims - 2, -1, -1):
                    if cols * (i + 1) % self._strides[d] == 0:
                        print_no_newline(" ]")

                if i < col_strides - 1:
                    print_no_newline(", ")
                    put_new_line()
                else:
                    print_no_newline(" ], shape: [")
                    for i in range(self._num_dims):
                        print_no_newline(self._shape[i])
                        if i < self._num_dims - 1:
                            print_no_newline(",")
                    print_no_newline("] ")
                    print_no_newline(">")
        print(" ")
