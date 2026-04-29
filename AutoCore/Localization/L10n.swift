import Foundation

/// Централизованные ключи локализации (EN в `Localizable.xcstrings` как source, RU — переводы).
enum L10n {
    private static func tr(_ key: String, _ english: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: english, comment: "")
    }

    enum App {
        static var databaseErrorTitle: String { tr("app.database_error_title", "Database error") }
    }

    enum Navigation {
        static var allMotors: String { tr("nav.all_motors", "All motors") }
        static var sold: String { tr("nav.sold", "Sold") }
        static var accounting: String { tr("nav.accounting", "Accounting") }
        static var warehouse: String { tr("nav.warehouse", "Warehouse") }
    }

    enum Sidebar {
        static var specificSection: String { tr("sidebar.specific_section", "Specific") }
        static var newCategoryHelp: String { tr("sidebar.new_category_help", "New category") }
        static var noCategories: String { tr("sidebar.no_categories", "No categories") }
        static var brands: String { tr("sidebar.brands", "Brands") }
        static var allBrands: String { tr("sidebar.all_brands", "All brands") }
    }

    enum Onboarding {
        static var welcome: String { tr("onboarding.welcome", "Welcome") }
        static var subtitle: String { tr("onboarding.subtitle", "Create a company or join an existing one with an invite code.") }
        static var createCompany: String { tr("onboarding.create_company", "Create company") }
        static var haveInviteCode: String { tr("onboarding.have_invite_code", "I have an invite code") }
        static var companyName: String { tr("onboarding.company_name", "Company name") }
        static var companyNamePlaceholder: String { tr("onboarding.company_name_placeholder", "Enter company name") }
        static var done: String { tr("onboarding.done", "Done") }
        static var create: String { tr("onboarding.create", "Create") }
        static var continue_: String { tr("onboarding.continue", "Continue") }
    }

    enum Login {
        static var appTitle: String { tr("login.app_title", "AutoCore Accounting") }
        static var createAccount: String { tr("login.create_account", "Create an account") }
        static var chooseSignIn: String { tr("login.choose_sign_in", "Choose a sign-in method") }
        static var signInGoogle: String { tr("login.sign_in_google", "Sign in with Google") }
        static var orEmail: String { tr("login.or_email", "or with email") }
        static var emailPlaceholder: String { tr("login.email_placeholder", "Email") }
        static var password: String { tr("login.password", "Password") }
        static var confirmPassword: String { tr("login.confirm_password", "Confirm password") }
        static var passwordsMismatch: String { tr("login.passwords_mismatch", "Passwords do not match") }
        static var invalidEmail: String { tr("login.invalid_email", "Enter a valid email address.") }
        static var forgotPassword: String { tr("login.forgot_password", "Forgot password?") }
        static var sendingReset: String { tr("login.sending_reset", "Sending reset email…") }
        static var resetEmailSentFormat: String { tr("login.reset_email_sent_format", "We sent reset instructions to %@.") }
        static var passwordMinLengthFormat: String {
            tr("login.password_min_length_format", "Password must be at least %lld characters.")
        }
        static var signIn: String { tr("login.sign_in", "Sign in") }
        static var signUp: String { tr("login.sign_up", "Sign up") }
        static var haveAccountSignIn: String { tr("login.have_account_sign_in", "Already have an account? Sign in") }
        static var noAccountRegister: String { tr("login.no_account_register", "No account? Register") }
        static func appleError(_ detail: String) -> String {
            String(format: tr("login.apple_error_format", "Apple sign-in error: %@"), detail)
        }
    }

    enum Common {
        static var systemUser: String { tr("common.system_user", "System") }
        static var cancel: String { tr("common.cancel", "Cancel") }
        static var add: String { tr("common.add", "Add") }
    }

    enum Root {
        static func updateError(_ detail: String) -> String {
            String(format: tr("root.update_error_format", "Update error: %@"), detail)
        }
        static func batchNoteTitle(_ count: Int) -> String {
            String(format: tr("root.batch_note_title_format", "Add note to %lld motors"), Int64(count))
        }
        static var batchNotePlaceholder: String { tr("root.batch_note_placeholder", "Note text") }
        static var batchNoteMessage: String {
            tr("root.batch_note_message", "The note will be appended to existing notes for the selected motors.")
        }
        static var recoveryMode: String { tr("root.recovery_mode", "Recovery mode") }
        static var warehouseUnavailableTitle: String { tr("root.warehouse_unavailable_title", "Warehouse unavailable") }
        static var warehouseUnavailableMessage: String {
            tr("root.warehouse_unavailable_message", "Could not determine the user’s company.")
        }
        static var categoryNotFoundTitle: String { tr("root.category_not_found_title", "Category not found") }
        static var categoryNotFoundMessage: String {
            tr("root.category_not_found_message", "The category was removed or does not exist.")
        }
        static var windowNotFound: String { tr("root.window_not_found", "Could not find the application window.") }
        static var chooseExcelFile: String { tr("root.choose_excel_file", "Choose Excel file") }
        static var exportExcel: String { tr("root.export_excel", "Export Excel") }
        static func exportError(_ detail: String) -> String {
            String(format: tr("root.export_error_format", "Export error: %@"), detail)
        }
        static var noDataToExport: String { tr("root.no_data_to_export", "No data to export") }
        static func createCategoryError(_ detail: String) -> String {
            String(format: tr("root.create_category_error_format", "Could not create category: %@"), detail)
        }
        static var engineNotFoundDuplicate: String { tr("root.engine_not_found_duplicate", "Could not find engine to duplicate.") }
        static var brandNotFoundDuplicate: String { tr("root.brand_not_found_duplicate", "Could not find brand to duplicate.") }
        static var motorDuplicated: String { tr("root.motor_duplicated", "Motor duplicated successfully.") }
        static var exportSingleMotorTitle: String { tr("root.export_single_motor_title", "Export motor") }
        static var exportSingleMotorPlaceholder: String {
            tr("root.export_single_motor_placeholder", "Single-motor export will be available in a future version.")
        }
    }

    enum IOS {
        static var loading: String { tr("ios.loading", "Loading…") }
        static var loadingData: String { tr("ios.loading_data", "Loading data…") }
        static var ensureCompanyFailed: String { tr("ios.ensure_company_failed", "Could not set up accounting") }
        static var retry: String { tr("ios.retry", "Retry") }
        static var createManually: String { tr("ios.create_manually", "Create manually") }
        static var creatingAccounting: String { tr("ios.creating_accounting", "Setting up your accounting…") }
    }

    enum Role {
        static var owner: String { tr("role.owner", "Owner") }
        static var admin: String { tr("role.admin", "Administrator") }
        static var accountant: String { tr("role.accountant", "Accountant") }
        static var employee: String { tr("role.employee", "Employee") }
        static var viewer: String { tr("role.viewer", "Viewer") }
    }

    enum Menu {
        static var undo: String { tr("menu.undo", "Undo") }
        static var redo: String { tr("menu.redo", "Redo") }
        static var newMotor: String { tr("menu.new_motor", "New motor") }
        static var importExcel: String { tr("menu.import_excel", "Import Excel") }
        static var exportExcel: String { tr("menu.export_excel", "Export Excel") }
        static var testerPanel: String { tr("menu.tester_panel", "Tester panel") }
        static var motorsMenu: String { tr("menu.motors", "Motors") }
        static var addMotor: String { tr("menu.add_motor", "Add motor") }
        static var markSold: String { tr("menu.mark_sold", "Mark as sold") }
        static var duplicate: String { tr("menu.duplicate", "Duplicate") }
        static var importFromExcel: String { tr("menu.import_from_excel", "Import from Excel") }
        static var exportToExcel: String { tr("menu.export_to_excel", "Export to Excel") }
    }

    enum Tester {
        static var windowTitle: String { tr("tester.window_title", "Tester panel") }
        static var close: String { tr("tester.close", "Close") }
        static var databaseStats: String { tr("tester.database_stats", "Database statistics") }
        static var tapRefreshStats: String { tr("tester.tap_refresh_stats", "Tap “Refresh statistics” to load.") }
        static var brands: String { tr("tester.brands", "Brands") }
        static var engines: String { tr("tester.engines", "Engines") }
        static var motors: String { tr("tester.motors", "Motors") }
        static var soldMotors: String { tr("tester.sold_motors", "Sold motors") }
        static var serviceRecords: String { tr("tester.service_records", "Service records") }
        static var specificCategories: String { tr("tester.specific_categories", "Specific categories") }
        static var specificRecordsNew: String { tr("tester.specific_records_new", "Specific records (new)") }
        static var byCategory: String { tr("tester.by_category", "By category:") }
        static var dataCleanup: String { tr("tester.data_cleanup", "Data cleanup") }
        static var specificData: String { tr("tester.specific_data", "Specific data") }
        static var deleteAllSpecificCategories: String { tr("tester.delete_all_specific_categories", "Delete all specific categories") }
        static var deleteAllSpecificRecords: String { tr("tester.delete_all_specific_records", "Delete all specific records") }
        static var deleteOldServiceRecords: String { tr("tester.delete_old_service_records", "Delete legacy service records") }
        static var deleteAllMotors: String { tr("tester.delete_all_motors", "Delete all motors") }
        static var deleteAllEngines: String { tr("tester.delete_all_engines", "Delete all engines") }
        static var deleteAllBrands: String { tr("tester.delete_all_brands", "Delete all brands") }
        static var clearEntireDatabase: String { tr("tester.clear_entire_database", "Clear entire database") }
        static var firestoreMigration: String { tr("tester.firestore_migration", "Firestore migration") }
        static var firestoreMigrationHint: String {
            tr("tester.firestore_migration_hint", "Upload all local financial operations to Firestore for the current company.")
        }
        static var migrateOperations: String { tr("tester.migrate_operations", "Migrate operations to Firestore") }
        static var utilities: String { tr("tester.utilities", "Utilities") }
        static var refreshStats: String { tr("tester.refresh_stats", "Refresh statistics") }
        static var copyStats: String { tr("tester.copy_stats", "Copy statistics") }
        static var optimizeDatabase: String { tr("tester.optimize_database", "Optimize database") }
        static var createBackup: String { tr("tester.create_backup", "Create backup") }
        static var confirmClearTitle: String { tr("tester.confirm_clear_title", "Clear all data?") }
        static var confirmClearMessage: String {
            tr("tester.confirm_clear_message", "This removes all local data for this account. This cannot be undone.")
        }
        static var confirmClearButton: String { tr("tester.confirm_clear_button", "Clear everything") }
        static var cancel: String { tr("tester.cancel", "Cancel") }
    }

    enum Recovery {
        static func databaseOpenFailed(_ detail: String) -> String {
            String(format: tr("recovery.database_open_failed_format", "Could not open the database: %@"), detail)
        }
        static func databaseValidationFailed(_ detail: String) -> String {
            String(format: tr("recovery.database_validation_failed_format", "Database validation error: %@"), detail)
        }
        static func migrationFailed(_ detail: String) -> String {
            String(format: tr("recovery.migration_failed_format", "Database migration error: %@"), detail)
        }
        static func operationBlocked(_ detail: String?) -> String {
            String(format: tr("recovery.operation_blocked_format", "Operation blocked in recovery mode. %@"), detail ?? "")
        }
    }

    enum AppState {
        static func databaseOpenFailed(_ detail: String) -> String {
            String(format: tr("app_state.database_open_failed_format", "Could not open the database: %@"), detail)
        }
        static var databaseReadonlyAccessErrors: String {
            tr("database.readonly_access_errors", "The database is open read-only due to access errors.")
        }
    }

    enum TesterError {
        static var statsFormat: String { tr("tester.error.stats_format", "Could not load statistics: %@") }
        static var deleteFormat: String { tr("tester.error.delete_format", "Delete failed: %@") }
        static var optimizeFormat: String { tr("tester.error.optimize_format", "Optimization failed: %@") }
        static var backupFormat: String { tr("tester.error.backup_format", "Backup failed: %@") }
        static var migrationFormat: String { tr("tester.error.migration_format", "Migration failed: %@") }
        static var companyRequired: String { tr("tester.error.company_required", "Sign in with a company to migrate.") }
    }

    enum TesterSuccess {
        static var serviceRecordsDeleted: String { tr("tester.success.service_records_deleted", "All legacy service records removed.") }
        static var motorsDeleted: String { tr("tester.success.motors_deleted", "All motors removed.") }
        static var enginesDeleted: String { tr("tester.success.engines_deleted", "All engines removed.") }
        static var brandsDeleted: String { tr("tester.success.brands_deleted", "All brands removed.") }
        static var specificCategoriesDeleted: String { tr("tester.success.specific_categories_deleted", "All specific categories removed.") }
        static var specificRecordsDeleted: String { tr("tester.success.specific_records_deleted", "All specific records removed.") }
        static var databaseCleared: String { tr("tester.success.database_cleared", "Local database cleared.") }
        static var optimized: String { tr("tester.success.optimized", "Database optimized.") }
        static var backupCreatedFormat: String { tr("tester.success.backup_created_format", "Backup created: %@") }
        static var migrationDoneFormat: String { tr("tester.success.migration_done_format", "Migration finished: %lld of %lld operations uploaded to Firestore.") }
    }

    enum TesterExport {
        static var statsNotLoaded: String { tr("tester.export.stats_not_loaded", "Statistics not loaded.") }
    }
}

extension UserRole {
    var localizedDisplayName: String {
        switch self {
        case .owner: return L10n.Role.owner
        case .admin: return L10n.Role.admin
        case .accountant: return L10n.Role.accountant
        case .employee: return L10n.Role.employee
        case .viewer: return L10n.Role.viewer
        }
    }
}
