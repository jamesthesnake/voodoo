from python import Python

from voodoo import Tensor, get_activation_code

alias TestSize = 10


fn test_fn[
    f: String
](
    tfFunction: PythonObject,
    tfConstant: PythonObject,
    tfType: PythonObject,
    tfSum: PythonObject,
) raises -> Int:
    var smallShape = DynamicVector[Int]()
    var mediumShape = DynamicVector[Int]()
    var largeShape = DynamicVector[Int]()

    smallShape.append(TestSize)
    smallShape.append(TestSize)
    mediumShape.append(TestSize)
    mediumShape.append(TestSize)
    mediumShape.append(TestSize)
    largeShape.append(TestSize)
    largeShape.append(TestSize)
    largeShape.append(TestSize)
    largeShape.append(TestSize)

    let smallTensorInitial = Tensor(smallShape).initialize["random_normal"]()
    let mediumTensorInitial = Tensor(mediumShape).initialize["random_normal"]()
    let largeTensorInitial = Tensor(largeShape).initialize["random_normal"]()

    let smallTensorActivated = smallTensorInitial.compute_activation[
        get_activation_code[f]()
    ]()
    let mediumTensorActivated = mediumTensorInitial.compute_activation[
        get_activation_code[f]()
    ]()
    let largeTensorActivated = largeTensorInitial.compute_activation[
        get_activation_code[f]()
    ]()

    let smallTest: PythonObject = []
    let mediumTest: PythonObject = []
    let largeTest: PythonObject = []

    let smallGuess: PythonObject = []
    let mediumGuess: PythonObject = []
    let largeGuess: PythonObject = []

    for i in range(TestSize**2):
        _ = smallTest.append(smallTensorInitial[i])
        _ = smallGuess.append(smallTensorActivated[i])

    for i in range(TestSize**3):
        _ = mediumTest.append(mediumTensorInitial[i])
        _ = mediumGuess.append(mediumTensorActivated[i])

    for i in range(TestSize**4):
        _ = largeTest.append(largeTensorInitial[i])
        _ = largeGuess.append(largeTensorActivated[i])

    let resultSmall = tfFunction(tfConstant(smallTest, tfType, [TestSize, TestSize]))
    let resultMedium = tfFunction(
        tfConstant(mediumTest, tfType, [TestSize, TestSize, TestSize])
    )
    let resultLarge = tfFunction(
        tfConstant(largeTest, tfType, [TestSize, TestSize, TestSize, TestSize])
    )

    let mojoResultSmall = tfConstant(smallGuess, tfType, [TestSize, TestSize])
    let mojoResultMedium = tfConstant(
        mediumGuess, tfType, [TestSize, TestSize, TestSize]
    )
    let mojoResultLarge = tfConstant(
        largeGuess, tfType, [TestSize, TestSize, TestSize, TestSize]
    )

    let resSmall: Bool = (
        tfSum(resultSmall.__abs__() - mojoResultSmall.__abs__()) < 0.05
    ).numpy().__bool__()
    let resMedium: Bool = (
        tfSum(resultMedium.__abs__() - mojoResultMedium.__abs__()) < 0.05
    ).numpy().__bool__()
    let resLarge: Bool = (
        tfSum(resultLarge.__abs__() - mojoResultLarge.__abs__()) < 0.05
    ).numpy().__bool__()

    print("----- Test for " + tfFunction.__name__.__str__() + " -----")
    if resSmall:
        print("✅ Small test passed")
    else:
        print("❌ Small test failed")

    if resMedium:
        print("✅ Medium test passed")
    else:
        print("❌ Medium test failed")

    if resLarge:
        print("✅ Large test passed")
    else:
        print("❌ Large test failed")

    if resSmall and resMedium and resLarge:
        print("----- All tests passed -----")
    else:
        print("----- Some tests failed -----")

    print("---------------------------------")

    var failed = 0
    if not resSmall:
        failed += 1
    if not resMedium:
        failed += 1
    if not resLarge:
        failed += 1

    return failed


fn main() raises:
    let tf = Python.import_module("tensorflow")
    var total = 0

    total += test_fn["relu"](
        tf.keras.activations.relu, tf.constant, tf.float32, tf.math.reduce_sum
    )
    total += test_fn["sigmoid"](
        tf.keras.activations.sigmoid,
        tf.constant,
        tf.float32,
        tf.math.reduce_sum,
    )

    total += test_fn["softmax"](
        tf.keras.activations.softmax,
        tf.constant,
        tf.float32,
        tf.math.reduce_sum,
    )

    total += test_fn["softplus"](
        tf.keras.activations.softplus,
        tf.constant,
        tf.float32,
        tf.math.reduce_sum,
    )

    total += test_fn["softsign"](
        tf.keras.activations.softsign,
        tf.constant,
        tf.float32,
        tf.math.reduce_sum,
    )

    total += test_fn["tanh"](
        tf.keras.activations.tanh, tf.constant, tf.float32, tf.math.reduce_sum
    )

    total += test_fn["selu"](
        tf.keras.activations.selu, tf.constant, tf.float32, tf.math.reduce_sum
    )

    total += test_fn["elu"](
        tf.keras.activations.elu, tf.constant, tf.float32, tf.math.reduce_sum
    )

    total += test_fn["exp"](
        tf.keras.activations.exponential,
        tf.constant,
        tf.float32,
        tf.math.reduce_sum,
    )

    total += test_fn["silu"](
        tf.keras.activations.swish, tf.constant, tf.float32, tf.math.reduce_sum
    )

    total += test_fn["gelu"](
        tf.keras.activations.gelu, tf.constant, tf.float32, tf.math.reduce_sum
    )


    total += test_fn["h_sig"](
        tf.keras.activations.hard_sigmoid,
        tf.constant,
        tf.float32,
        tf.math.reduce_sum,
    )

    total += test_fn["linear"](
        tf.keras.activations.linear, tf.constant, tf.float32, tf.math.reduce_sum
    )

    total += test_fn["mish"](
        tf.keras.activations.mish, tf.constant, tf.float32, tf.math.reduce_sum
    )
    
    if total == 0:
        print("✅ All tests passed")
    elif total == 1:
        print("❌ ", total, " test failed")
    else:
        print("❌ ", total, " tests failed")
