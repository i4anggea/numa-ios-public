import XCTest

@MainActor final class FinanceUITests: XCTestCase {
    func testTenThousandHistoryPerformance() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let token = UUID().uuidString
        print("FINANCE_PERFORMANCE_STORE=" + token)
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(es)", "-AppleLocale", "es_MX"]
        app.launchEnvironment = ["FINANCE_TEST_STORE": token, "FINANCE_TEST_SCENARIO": "large", "FINANCE_PERFORMANCE": "1"]
        app.launch()
        XCTAssertTrue(app.buttons["accounts.open"].waitForExistence(timeout: 40))
        if app.buttons["Mostrar importes"].exists { app.buttons["Mostrar importes"].tap() }
        for _ in 0..<3 {
            app.terminate(); app.launch()
            XCTAssertTrue(app.buttons["accounts.open"].waitForExistence(timeout: 40))
        }
        app.buttons["movement.add"].tap()
        replace(app.textFields["money.Importe"], with: "12.34")
        app.buttons["movement.category"].tap(); app.buttons["Alimentación"].tap()
        app.buttons["movement.method"].tap(); app.buttons["Banco 1 · Cuenta"].tap()
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.buttons["accounts.open"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Movimientos"].tap()
        XCTAssertTrue(app.navigationBars["Movimientos"].waitForExistence(timeout: 15))
        let count = app.staticTexts["history.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 15))
        let parts = count.label.components(separatedBy: "·")
        XCTAssertEqual(parts.first?.filter(\.isNumber), "10001", "El total filtrado debe considerar todos los registros")
        XCTAssertEqual(parts.last?.filter(\.isNumber), "50", "La vista debe comenzar con un bloque de 50")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Filtros")).firstMatch.tap()
        app.buttons["history.category"].tap(); app.buttons["Transporte"].tap()
        let filtered = app.staticTexts.matching(NSPredicate(format: "identifier == 'history.count' AND label BEGINSWITH '500 movimientos'")).firstMatch
        XCTAssertTrue(filtered.waitForExistence(timeout: 10), "La categoría debe buscar en los 10001 registros, no solo en los 50 visibles")
        app.buttons["Restablecer filtros"].tap()
        reveal(app.staticTexts["history.count"], in: app, upwards: false)
        capture(app, name: "Historial después de restablecer filtros")
        XCTAssertEqual(count.label.components(separatedBy: "·").first?.filter(\.isNumber), "10001")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Filtros")).firstMatch.tap()
        let later = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Movimiento de prueba 9940")).firstMatch
        XCTAssertFalse(later.exists)
        reveal(later, in: app, upwards: true, attempts: 20)
        capture(app, name: "Carga progresiva sobre 10001 movimientos")
        app.tabBars.buttons["Reportes"].tap()
        XCTAssertTrue(app.staticTexts["Gastos de consumo"].waitForExistence(timeout: 15))
        capture(app, name: "Reporte con 10001 movimientos ficticios")
    }
    private func launch(scenario: String? = nil) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(es)", "-AppleLocale", "es_MX"]
        app.launchEnvironment["FINANCE_TEST_STORE"] = UUID().uuidString
        if let scenario { app.launchEnvironment["FINANCE_TEST_SCENARIO"] = scenario }
        app.launch()
        XCTAssertTrue(app.buttons["accounts.open"].waitForExistence(timeout: 15))
        if app.buttons["Mostrar importes"].exists { app.buttons["Mostrar importes"].tap() }
        return app
    }
    private func replace(_ field: XCUIElement, with value: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let count = (field.value as? String)?.count ?? 0
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + value)
        XCTAssertEqual(field.value as? String, value, "La captura debe coincidir antes de guardar")
        let done = XCUIApplication().toolbars.buttons["Listo"].firstMatch
        if done.exists && done.isHittable { done.tap() }
    }
    private func text(_ app: XCUIApplication, containing value: String) -> XCUIElement {
        let scope: XCUIElement = app.collectionViews.allElementsBoundByIndex.last ?? app
        return scope.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = true, attempts: Int = 6) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.exists && element.isHittable, "El control debe poder alcanzarse desplazando la pantalla")
    }
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testValidationAndNegativeBalanceConfirmation() throws {
        let app = launch(scenario: "credit")
        app.buttons["movement.add"].tap()
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.alerts["Revisa los datos"].waitForExistence(timeout: 5))
        app.alerts.buttons["Entendido"].tap()
        replace(app.textFields["money.Importe"], with: "6000")
        app.buttons["movement.category"].tap(); app.buttons["Alimentación"].tap()
        app.buttons["movement.method"].tap(); app.buttons["Banco · Cuenta"].tap()
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.alerts["Confirma el registro"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancelar"].tap()
        XCTAssertTrue(app.textFields["money.Importe"].exists, "Cancelar debe conservar el formulario")
        app.navigationBars.buttons["Guardar"].tap()
        app.alerts.buttons["Registrar de todos modos"].tap()
        XCTAssertTrue(app.staticTexts["-$1,000.00"].waitForExistence(timeout: 5), "La confirmación debe guardar el movimiento exactamente una vez")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["-$1,000.00"].waitForExistence(timeout: 10))
        capture(app, name: "Registro confirmado con saldo negativo")
    }
    func testCompletedWeekClosureSavingsAndDependentReopen() throws {
        let app = launch(scenario: "week")
        XCTAssertTrue(app.staticTexts["$1,700.00"].exists)
        app.tabBars.buttons["Presupuestos"].tap()
        app.buttons["Semana anterior"].tap()
        capture(app, name: "Semana previa antes del reparto")
        XCTAssertTrue(text(app, containing: "$700.00").waitForExistence(timeout: 5))
        app.buttons["Cerrar y repartir sobrante"].tap()
        replace(app.textFields["money.Reservar para ahorro"], with: "200")
        app.buttons["closure.goal"].tap(); app.buttons["Fondo"].tap()
        app.buttons["closure.account"].tap(); app.buttons["Banco"].tap()
        replace(app.textFields["money.Añadir al límite global siguiente"], with: "300")
        app.navigationBars.buttons["Confirmar"].tap()
        XCTAssertTrue(app.staticTexts["Semana cerrada"].waitForExistence(timeout: 5))
        capture(app, name: "Cierre semanal con ahorro y margen trasladado")
        app.buttons["Semana siguiente"].tap()
        XCTAssertTrue(text(app, containing: "$300.00").waitForExistence(timeout: 5))
        app.tabBars.buttons["Inicio"].tap()
        XCTAssertTrue(app.staticTexts["$1,500.00"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Ahorro"].tap()
        app.staticTexts["Fondo"].tap()
        app.buttons["Aportar o liberar dinero"].tap()
        app.buttons["Liberar"].tap()
        app.buttons["savings.account"].tap(); app.buttons["Banco"].tap()
        replace(app.textFields["money.Importe"], with: "100")
        app.navigationBars.buttons["Confirmar"].tap()
        XCTAssertTrue(app.buttons["Aportar o liberar dinero"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Inicio"].tap()
        XCTAssertTrue(app.staticTexts["$1,600.00"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Presupuestos"].tap()
        app.buttons["Semana anterior"].tap()
        reveal(app.buttons["Deshacer reparto"], in: app)
        app.buttons["Deshacer reparto"].tap()
        app.sheets.buttons["Deshacer reparto"].tap()
        XCTAssertTrue(app.alerts["No se pudo completar"].waitForExistence(timeout: 5))
        app.alerts.buttons["Entendido"].tap()
        XCTAssertTrue(app.staticTexts["Semana cerrada"].exists)
    }
    func testCreditPaymentCorrectionAndProtectedDeletionInSheet() throws {
        let app = launch(scenario: "credit")
        app.buttons["movement.add"].tap()
        app.buttons["movement.kind"].tap(); app.buttons["Pago de tarjeta"].tap()
        replace(app.textFields["money.Importe"], with: "400.34")
        app.buttons["accountPicker.Pagar desde"].tap(); app.buttons["Banco"].tap()
        app.buttons["payment.card"].tap(); app.buttons["Crédito de prueba"].tap()
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.staticTexts["$800.66"].waitForExistence(timeout: 5))
        app.buttons["accounts.open"].tap()
        app.staticTexts["Crédito de prueba"].tap()
        let purchases = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Compra de prueba")).allElementsBoundByIndex
        try XCTUnwrap(purchases.last(where: { $0.isHittable })).tap()
        XCTAssertTrue(text(app, containing: "Con intereses").waitForExistence(timeout: 5))
        reveal(app.buttons["Editar movimiento"], in: app)
        app.buttons["Editar movimiento"].tap()
        replace(app.textFields["money.Total final a pagar"], with: "1301")
        app.navigationBars.buttons["Guardar"].tap()
        reveal(text(app, containing: "$1,301.00"), in: app, upwards: false)
        XCTAssertTrue(text(app, containing: "$1,301.00").waitForExistence(timeout: 5))
        capture(app, name: "Compra a meses corregida con pago parcial")
        reveal(app.buttons["Eliminar movimiento"], in: app)
        app.buttons["Eliminar movimiento"].tap()
        app.buttons["Eliminar"].tap()
        XCTAssertTrue(app.alerts["No se pudo completar"].waitForExistence(timeout: 5), "El error debe presentarse dentro de la hoja activa")
        app.alerts.buttons["Entendido"].tap()
        XCTAssertTrue(app.buttons["Editar movimiento"].exists, "Una eliminación inválida debe conservar el detalle de la compra")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["$900.66"].waitForExistence(timeout: 10))
    }
    func testQuickCashConfigurationCancellationAndSave() throws {
        let app = launch(scenario: "week")
        app.buttons["Ajustes"].tap()
        app.buttons["settings.shortcuts"].tap()
        app.buttons["quick.cash"].tap(); app.buttons["Efectivo"].tap()
        app.buttons["quick.category"].tap(); app.buttons["Alimentación"].tap()
        capture(app, name: "Configuración de Atajos y efectivo predeterminado")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons["Listo"].tap()
        reveal(app.buttons["quick.open"], in: app)
        app.buttons["quick.open"].tap()
        XCTAssertTrue(app.textFields["money.Importe"].waitForExistence(timeout: 5))
        replace(app.textFields["money.Importe"], with: "125.50")
        app.navigationBars.buttons["Cancelar"].tap()
        reveal(app.staticTexts["$1,700.00"], in: app, upwards: false)
        app.buttons["quick.open"].tap()
        replace(app.textFields["money.Importe"], with: "125.50")
        app.navigationBars.buttons["Guardar"].tap()
        reveal(app.staticTexts["$1,574.50"], in: app, upwards: false)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["$1,574.50"].waitForExistence(timeout: 10))
        capture(app, name: "Gasto rápido en efectivo guardado tras confirmación")
    }
    func testDetectedPurchaseRequiresAmountAndWarnsAboutDuplicates() throws {
        let app = launch(scenario: "shortcuts")
        app.buttons["quick.open"].tap()
        let notification = app.buttons["capture.santanderNotification"]
        XCTAssertTrue(notification.waitForExistence(timeout: 5))
        notification.tap()
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.alerts["Revisa los datos"].waitForExistence(timeout: 5))
        app.alerts.buttons["Entendido"].tap()
        replace(app.textFields["money.Importe"], with: "125.50")
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.alerts["Confirma el registro"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancelar"].tap()
        app.navigationBars.buttons["Cancelar"].tap()
        XCTAssertTrue(notification.waitForExistence(timeout: 5), "Cancelar conserva el pendiente")
        notification.tap()
        replace(app.textFields["money.Importe"], with: "125.50")
        app.navigationBars.buttons["Guardar"].tap()
        app.alerts.buttons["Registrar de todos modos"].tap()
        XCTAssertFalse(notification.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["capture.santanderEmail"].exists)
        app.navigationBars.buttons["Listo"].tap()
        reveal(app.staticTexts["$1,074.50"], in: app, upwards: false)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["$1,074.50"].waitForExistence(timeout: 10))
        app.buttons["quick.open"].tap()
        XCTAssertTrue(app.textFields["money.Importe"].waitForExistence(timeout: 5), "Un pendiente abre su formulario directamente")
        capture(app, name: "Compra detectada pendiente con moneda e importe por revisar")
        app.navigationBars.buttons["Cancelar"].tap()
    }

    func testCashCanBeAddedInsideExpenseAndCancellationKeepsDraft() throws {
        let app = launch()
        app.buttons["movement.add"].tap()
        replace(app.textFields["money.Importe"], with: "125.50")
        app.buttons["movement.category"].tap(); app.buttons["Alimentación"].tap()
        app.buttons["movement.method"].tap(); app.buttons["Efectivo"].tap()
        XCTAssertTrue(app.navigationBars["Añadir efectivo"].waitForExistence(timeout: 5))
        app.navigationBars["Añadir efectivo"].buttons["Cancelar"].tap()
        XCTAssertTrue(app.textFields["money.Importe"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["money.Importe"].value as? String, "125.50")
        app.buttons["movement.method"].tap(); app.buttons["Efectivo"].tap()
        replace(app.textFields["money.Saldo inicial"], with: "1000")
        app.navigationBars["Añadir efectivo"].buttons["Guardar"].tap()
        XCTAssertTrue(app.textFields["money.Importe"].waitForExistence(timeout: 5))
        capture(app, name: "Efectivo seleccionado sin tratarlo como cuenta bancaria")
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.staticTexts["$874.50"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["$874.50"].waitForExistence(timeout: 10))
        app.buttons["accounts.open"].tap()
        XCTAssertTrue(app.buttons["Añadir efectivo"].exists)
        XCTAssertTrue(app.staticTexts["$874.50"].exists)
    }

    func testSavingsMilestoneIsHiddenWithAmounts() throws {
        let app = launch(scenario: "week")
        app.tabBars.buttons["Ahorro"].tap()
        app.staticTexts["Fondo"].tap()
        app.buttons["Aportar o liberar dinero"].tap()
        app.buttons["savings.account"].tap(); app.buttons["Banco"].tap()
        replace(app.textFields["money.Importe"], with: "1250")
        app.navigationBars.buttons["Confirmar"].tap()
        let progress = app.staticTexts["goal.progressPercent"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.label, "25 % de tu meta")
        XCTAssertTrue(app.descendants(matching: .any)["goal.milestone"].exists)
        capture(app, name: "Primer hito de ahorro con progreso real")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Ocultar importes"].tap()
        app.staticTexts["Fondo"].tap()
        XCTAssertTrue(app.staticTexts["Progreso oculto"].waitForExistence(timeout: 5))
        XCTAssertFalse(progress.exists)
        XCTAssertFalse(app.descendants(matching: .any)["goal.milestone"].exists)
        capture(app, name: "Progreso y logro ocultos junto con los importes")
    }

    func testCreateExpensePersistsAndPrivacyHidesIt() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(es)", "-AppleLocale", "es_MX"]
        app.launchEnvironment["FINANCE_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["accounts.open"].waitForExistence(timeout: 15))
        app.buttons["accounts.open"].tap()
        app.buttons["Añadir efectivo"].tap()
        let name = app.textFields["account.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replace(name, with: "Efectivo de prueba")
        let opening = app.textFields["money.Saldo inicial"]
        replace(opening, with: "1000")
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.staticTexts["Efectivo · Efectivo de prueba"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Listo"].tap()
        XCTAssertTrue(app.staticTexts["$1,000.00"].waitForExistence(timeout: 5))
        app.buttons["movement.add"].tap()
        let amount = app.textFields["money.Importe"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap(); amount.typeText("125.50")
        app.buttons["movement.category"].tap()
        app.buttons["Alimentación"].tap()
        app.buttons["movement.method"].tap()
        app.buttons["Efectivo · Efectivo de prueba"].tap()
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.staticTexts["$874.50"].waitForExistence(timeout: 5))
        let populated = XCTAttachment(screenshot: app.screenshot())
        populated.name = "Inicio con un gasto registrado"
        populated.lifetime = .keepAlways
        add(populated)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["$874.50"].waitForExistence(timeout: 10), "Persistencia tras reapertura")
        app.buttons["Ocultar importes"].tap()
        XCTAssertFalse(app.staticTexts["$874.50"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Mostrar importes"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["$874.50"].exists)
        app.buttons["Mostrar importes"].tap()
        app.tabBars.buttons["Reportes"].tap()
        XCTAssertTrue(app.staticTexts["Gastos de consumo"].waitForExistence(timeout: 5))
        let report = XCTAttachment(screenshot: app.screenshot())
        report.name = "Reporte del gasto"
        report.lifetime = .keepAlways
        add(report)
    }
}
