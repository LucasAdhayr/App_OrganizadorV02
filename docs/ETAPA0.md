# ETAPA 0: PREPARAR O AMBIENTE (WINDOWS)

Objetivo: rodar um app "Olá" no seu Poco X3 e criar a chave de assinatura. Faça em ordem e me diga em qual passo travar.

## 1. Instalar o Android Studio
1. Baixe em https://developer.android.com/studio e instale com as opções padrão.
2. Abra uma vez e conclua o assistente inicial (ele baixa o Android SDK).
3. Em `More Actions > SDK Manager > SDK Tools`, marque **Android SDK Command-line Tools (latest)** e aplique.

## 2. Instalar o Flutter
1. Em https://docs.flutter.dev/get-started/install/windows baixe o SDK e extraia em `C:\src\flutter`. Evite pastas com espaço ou `Program Files`.
2. Adicione `C:\src\flutter\bin` à variável de ambiente `Path` do usuário.
3. Abra um **novo** terminal e rode:
   ```
   flutter doctor
   flutter doctor --android-licenses
   ```
   Aceite todas as licenças com `y`.
4. Rode `flutter doctor` de novo. O que precisa estar verde: Flutter, Android toolchain, Connected device. Chrome e Visual Studio podem ficar com aviso, pois não usaremos.

## 3. VS Code
Instale as extensões **Flutter** e **Dart**.

## 4. Ligar a depuração USB no Poco X3 (MIUI)
1. `Configurações > Sobre o telefone`, toque 7 vezes em **Versão do MIUI**.
2. `Configurações adicionais > Opções do desenvolvedor`.
3. Ative **Depuração USB**, **Instalar via USB** e **Depuração USB (configurações de segurança)**. As duas últimas costumam exigir login em conta Mi e chip com dados.
4. Conecte o cabo, escolha **Transferência de arquivos** e aceite o aviso "Permitir depuração USB".
5. No terminal, `flutter devices` deve listar o aparelho.

## 5. App de teste
```
cd C:\dev
flutter create --org br.pessoal --platforms android teste_ola
cd teste_ola
flutter run
```
O primeiro build demora. Quando o contador aparecer no celular, o ambiente está pronto.

## 6. Chave de assinatura (importante)
Se o APK for assinado com chaves diferentes, o Android recusa a atualização e você teria que desinstalar, o que **apaga os dados do app**.

1. Crie a chave **fora** do repositório, por exemplo em `C:\chaves`:
   ```
   mkdir C:\chaves
   keytool -genkey -v -keystore C:\chaves\organizador.jks -keyalg RSA -keysize 2048 -validity 10000 -alias organizador
   ```
   Se `keytool` não for encontrado, use o caminho do JDK do Android Studio: `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`.
2. Anote a senha em um gerenciador de senhas.
3. **Copie o arquivo `.jks` e a senha para um lugar seguro** (pen drive, nuvem pessoal). Perder a chave tem o mesmo efeito de trocar a assinatura.
4. Nunca coloque o `.jks` nem a senha no GitHub.

## 7. Clonar o repositório
```
cd C:\dev
git clone https://github.com/lucastoledoeng-web/organizador-pessoal.git
```
Copie para dentro dele a pasta `docs` com os dois arquivos. Depois:
```
git add docs
git commit -m "docs: decisões fechadas e guia da etapa 0"
git push
```

## O que me enviar ao terminar
- A saída completa de `flutter doctor` (copie e cole).
- Se o app de teste abriu no celular.
- Se o repositório foi clonado.
