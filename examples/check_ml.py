"""Verifica se as bibliotecas de IA estão funcionando e faz um teste rápido do PyTorch."""
import importlib
import platform
import time

LIBS = [
    ("numpy", "NumPy"),
    ("scipy", "SciPy"),
    ("pandas", "pandas"),
    ("PIL", "Pillow"),
    ("matplotlib", "Matplotlib"),
    ("torch", "PyTorch"),
    ("torchvision", "torchvision"),
    ("torchaudio", "torchaudio"),
    ("onnxruntime", "ONNX Runtime"),
    ("tflite_runtime", "TFLite (opcional)"),
    ("cv2", "OpenCV (opcional)"),
]


def check(module: str):
    try:
        m = importlib.import_module(module)
        return True, getattr(m, "__version__", "?")
    except Exception as exc:  # ImportError, mas também erros de .so faltando
        return False, f"{type(exc).__name__}: {exc}".splitlines()[0][:70]


def torch_smoke_test() -> None:
    import torch

    print(f"\nPyTorch {torch.__version__} | threads: {torch.get_num_threads()}")
    a = torch.randn(512, 512)
    start = time.perf_counter()
    for _ in range(10):
        a @ a
    ms = (time.perf_counter() - start) * 100
    print(f"Multiplicação de matrizes 512x512: {ms:.1f} ms por operação")

    # Treina uma rede minúscula para ter certeza que autograd funciona.
    model = torch.nn.Sequential(torch.nn.Linear(2, 8), torch.nn.ReLU(), torch.nn.Linear(8, 1))
    opt = torch.optim.SGD(model.parameters(), lr=0.1)
    x = torch.tensor([[0.0, 0.0], [0.0, 1.0], [1.0, 0.0], [1.0, 1.0]])
    y = torch.tensor([[0.0], [1.0], [1.0], [0.0]])  # XOR
    torch.manual_seed(0)
    for _ in range(500):
        opt.zero_grad()
        loss = torch.nn.functional.mse_loss(model(x), y)
        loss.backward()
        opt.step()
    print(f"Rede XOR treinada, erro final: {loss.item():.4f}")


def main() -> int:
    print(f"Python {platform.python_version()} em {platform.machine()}\n")
    width = max(len(name) for _, name in LIBS)
    required_missing = 0
    for module, name in LIBS:
        good, info = check(module)
        mark = "\033[32m✔\033[0m" if good else "\033[31m✖\033[0m"
        print(f" {mark} {name:<{width}}  {info}")
        if not good and "opcional" not in name:
            required_missing += 1
    if check("torch")[0]:
        torch_smoke_test()
    return 1 if required_missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
