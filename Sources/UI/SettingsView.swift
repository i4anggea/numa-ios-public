import SwiftUI

struct SettingsView: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("theme") private var theme = "system"
    @AppStorage("hideAmounts") private var hidden = false
    var body: some View {
        Form {
            Section("Apariencia y privacidad") {
                Picker("Tema", selection: $theme) {
                    Text("Sistema").tag("system"); Text("Claro").tag("light"); Text("Oscuro").tag("dark")
                }
                Toggle("Ocultar importes y gráficas", isOn: $hidden)
                Text("La preferencia se recuerda. Al editar, los formularios muestran el importe. Esta versión no utiliza Face ID ni código propio.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Atajos") { NavigationLink("Atajos y captura rápida") { QuickCaptureSettingsView() }.accessibilityIdentifier("settings.shortcuts") }
            Section("Organización") { NavigationLink("Categorías") { CategoriesView() } }
            Section("Recordatorios locales") {
                Text(store.notificationStatus).font(.callout)
                Button("Activar o actualizar avisos") { Task { await store.refreshNotifications(request: true) } }
                Button("Abrir ajustes de iOS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Text("Hasta 60 avisos próximos se renuevan al abrir la app. Si no vuelves a abrirla, el calendario programado puede agotarse. La entrega depende de los permisos y ajustes de iOS.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Tus datos") {
                Text("Solo en este iPhone, sin cuenta ni conexión bancaria.")
                Text("La base financiera se excluye de las copias del sistema. Esta versión no incluye exportación ni restauración: si eliminas la app o pierdes el dispositivo, no podrás recuperar sus registros.").font(.callout)
                Text("Moneda: MXN · Idioma: español · Semanas: lunes a domingo · Calendario contable y avisos: Ciudad de México.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Versión de desarrollo") { Text("Numa\n\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Desarrollo") · Pruebas privadas").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Ajustes")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
    }
}
struct CategoriesView: View {
    @Environment(FinanceStore.self) private var store
    @State private var name = ""
    @State private var editing: Category?
    @State private var error: String?
    var body: some View {
        List {
            Section(editing == nil ? "Añadir categoría" : "Renombrar categoría") {
                TextField("Nombre", text: $name)
                Button(editing == nil ? "Añadir" : "Guardar nombre") { save() }
                if editing != nil { Button("Cancelar edición") { editing = nil; name = "" } }
                if let error { Text(error).foregroundStyle(.red).font(.callout) }
            }
            Section("Categorías") {
                ForEach(store.ledger.categories.sorted { $0.name < $1.name }) { category in
                    HStack {
                        VStack(alignment: .leading) { Text(category.name); if category.archived { Text("Archivada").font(.caption).foregroundStyle(.secondary) } }
                        Spacer()
                        Menu {
                            Button("Renombrar") { editing = category; name = category.name }
                            Button(category.archived ? "Restaurar" : "Archivar") {
                                store.change { state in if let i = state.categories.firstIndex(where: { $0.id == category.id }) { state.categories[i].archived.toggle() } }
                            }
                        } label: { Image(systemName: "ellipsis.circle").padding(8) }.accessibilityLabel("Opciones de " + category.name)
                    }
                }
            }
            Section { Text("Archivar evita usar una categoría en movimientos nuevos y conserva su historial. Puedes restaurarla cuando quieras.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Categorías")
    }
    private func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 60 else { error = "Introduce un nombre de hasta 60 caracteres."; return }
        guard !store.ledger.categories.contains(where: { $0.id != editing?.id && $0.name.compare(clean, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) else {
            error = "Ya existe una categoría con ese nombre."; return
        }
        if store.change({ state in
            if let editing, let i = state.categories.firstIndex(where: { $0.id == editing.id }) { state.categories[i].name = clean }
            else { state.categories.append(Category(clean)) }
        }) { name = ""; editing = nil; error = nil }
        else { error = store.errorMessage; store.errorMessage = nil }
    }
}
