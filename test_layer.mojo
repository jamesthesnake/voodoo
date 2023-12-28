from voodoo import Tensor, Dense, sin, mse, Graph
from voodoo.utils.shape import shape
from time.time import now


fn nanoseconds_to_seconds(t: Int) -> Float64:
    return Float64(t) / 1_000_000_000.0


fn main() raises:
    let l1 = Dense[activation="relu"](1, 64)
    let l2 = Dense[activation="relu"](64, 64)
    let l3 = Dense(64, 1)

    var avg_loss: Float32 = 0.0
    let every = 1000
    let num_epochs = 20000

    let initial_start = now()
    for epoch in range(1, num_epochs + 1):
        let epoch_start = now()
        let input = Tensor(shape(32, 1)).random_uniform(0, 1).dynamic()
        let true_vals = sin(15.0 * input)

        var x = l1.forward(input)
        x = l2.forward(x)
        x = l3.forward(x)
        let loss = mse(x, true_vals)

        avg_loss += loss[0]
        if epoch % every == 0:
            print(
                "Epoch:",
                epoch,
                " Avg Loss: ",
                avg_loss / every,
                " Time: ",
                nanoseconds_to_seconds(now() - epoch_start),
                "s",
            )
            avg_loss = 0.0

        loss.backward()
        loss.optimize["sgd"](0.01)

        loss.clear()
        input.free()

    print("Total Time: ", nanoseconds_to_seconds(now() - initial_start), "s")
