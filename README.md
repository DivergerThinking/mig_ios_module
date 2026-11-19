## README.md


# MadridInGameiOSModule

## Requisitos

- iOS 16.0 o superior
- Swift 5.10 o superior

## Instalación

### Swift Package Manager (recomendado)

En Xcode: **File → Add Package Dependencies…** e introduce la URL del repositorio, o añádelo a tu `Package.swift`:

```swift
.package(
    url: "https://github.com/DivergerThinking/mig_ios_module.git",
    from: "1.1.0"
)
```

### CocoaPods (hasta diciembre de 2026)

Para integrar **MadridInGameiOSModule** usando CocoaPods, añade a tu `Podfile`:

```ruby
pod 'MadridInGameiOSModule', :git => 'https://github.com/DivergerThinking/mig_ios_module.git', :tag => '1.1.0'
```

Luego, ejecuta:

```bash
pod install
```

### Uso

```swift
import MadridInGameiOSModule
```

Desde la versión **2.0.0** el módulo se autentica con el **`id_token` de Azure AD B2C** de la sesión que ya tiene la app (MSAL). El módulo abre con él su propia sesión segura en el servidor de Madrid in Game y, cuando caduca (1 h), pide un token nuevo a la app mediante `idTokenProvider`. La app **no** pasa email, DNI ni nombre: la identidad sale del token validado en el servidor.

```swift
struct EsportsView: View {
    let idToken: String        // MSALResult.idToken de la sesión actual
    let auth: AuthService      // vuestro wrapper de MSAL

    var body: some View {
        MadridInGameiOSModule(
            idToken: idToken,
            idTokenProvider: { forceRefresh in
                // acquireTokenSilent(forceRefresh:) y devolver result.idToken.
                // Lanzad un error si el usuario tiene que volver a iniciar sesión.
                try await auth.silentIdToken(forceRefresh: forceRefresh)
            },
            logoMIG: UIImage(named: "logo_mig"),
            qrMiddleLogo: UIImage(named: "qr_middle_logo")
        )
    }
}
```

### Parámetros

- **idToken: String** — `id_token` de B2C de la sesión actual, sin modificar.
- **idTokenProvider: (Bool) async throws -> String** — el módulo lo llama cuando necesita un token nuevo. Con `forceRefresh == true` el anterior fue rechazado: pedid uno nuevo a MSAL. Si MSAL requiere interacción, lanzad un error y el módulo mostrará «sesión caducada» (sin bucles).
- **logoMIG: UIImage?** — logo mostrado en la cabecera.
- **qrMiddleLogo: UIImage?** — logo centrado en los códigos QR de las reservas.
- **isPreRelease: Bool** — `true` para el entorno PRE (por defecto `false`, PRO).

### Migración desde 1.x

`init(_ model:)`, `init(email:userName:dni:accessToken:…)` y `MadridInGameUserData` se han eliminado: el token estático de Directus ya no es válido. Sustituid la llamada por el inicializador anterior.

## Licencia

MadridInGameModule está licenciado bajo la [MIT License](LICENSE).

---

## LICENSE

MIT License

Copyright (c) 2024 Madrid In Game

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

