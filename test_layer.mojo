from time.time import now
from tensor import TensorShape

from voodoo.core import Tensor, HeNormal, RandomUniform, SGD
from voodoo.core.layers import Dense, LeakyReLu
from voodoo.utils import (
    info,
    clear,
)


fn nanoseconds_to_seconds(t: Int) -> Float64:
    return t / 1_000_000_000.0


alias data_shape = TensorShape(32, 1)


fn main() raises:
    let input_layer = Dense[
        in_neurons=1,
        out_neurons=32,
        activation="relu",
        weight_initializer = HeNormal[1],
        bias_initializer = HeNormal[32],
    ]()
    let leaky_relu = LeakyReLu[
        in_neurons=32,
        out_neurons=32,
        weight_initializer = HeNormal[32],
        bias_initializer = HeNormal[32],
    ]()
    let dense_layer = LeakyReLu[
        in_neurons=32,
        out_neurons=32,
        weight_initializer = HeNormal[32],
        bias_initializer = HeNormal[32],
    ]()
    let output_layer = Dense[
        in_neurons=32,
        out_neurons=1,
        weight_initializer = HeNormal[32],
        bias_initializer = HeNormal[1],
    ]()

    var avg_loss: Float32 = 0.0
    let every = 1000
    let num_epochs = 2000000

    let input = Tensor[data_shape, RandomUniform[0, 1]]()
    let true_vals = Tensor[data_shape, RandomUniform[0, 1]]()

    var x = input_layer.forward(input)
    x = leaky_relu.forward(x)
    x = dense_layer.forward(x)
    x = output_layer.forward(x)
    var loss = x.compute_loss["mse"](true_vals)

    let initial_start = now()
    var epoch_start = now()
    let bar_accuracy = 20
    for epoch in range(1, num_epochs + 1):
        input.refresh()
        for i in range(data_shape.num_elements()):
            true_vals[i] = math.sin(15.0 * input[i])

        var computed_loss = loss.forward_static()
        avg_loss += computed_loss[0]
        loss.backward()
        loss.optimize[SGD[0.01]]()

        if epoch % every == 0:
            var bar = String("")
            for i in range(bar_accuracy):
                if i < ((epoch * bar_accuracy) / num_epochs).to_int():
                    bar += "█"
                else:
                    bar += "░"
            clear()
            print_no_newline("\nEpoch: " + String(epoch) + " ")
            info(bar + " ")
            print_no_newline(String(((epoch * 100) / num_epochs).to_int()) + "%\n")
            print("----------------------------------------\n")
            print_no_newline("Average Loss: ")
            info(String(avg_loss / every) + "\n")
            print_no_newline("Time: ")
            info(String(nanoseconds_to_seconds(now() - epoch_start)) + "s\n")
            epoch_start = now()
            print("\n----------------------------------------\n")
            avg_loss = 0.0

    print_no_newline("Total Time: ")
    info(String(nanoseconds_to_seconds(now() - initial_start)) + "s\n\n")
