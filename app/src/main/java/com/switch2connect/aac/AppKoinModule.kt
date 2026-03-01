package com.switch2connect.aac

import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import com.switch2connect.aac.facetracking.FaceTrackingViewModel
import com.switch2connect.aac.presets.ILegacyCategoriesAndPhrasesRepository
import com.switch2connect.aac.presets.LegacyCategoriesAndPhrasesRepository
import com.switch2connect.aac.presets.PresetCategoriesRepository
import com.switch2connect.aac.presets.PresetsViewModel
import com.switch2connect.aac.presets.RoomPresetCategoriesRepository
import com.switch2connect.aac.room.PresetPhrasesRepository
import com.switch2connect.aac.room.RoomPresetPhrasesRepository
import com.switch2connect.aac.room.RoomStoredCategoriesRepository
import com.switch2connect.aac.room.RoomStoredPhrasesRepository
import com.switch2connect.aac.room.StoredCategoriesRepository
import com.switch2connect.aac.room.StoredPhrasesRepository
import com.switch2connect.aac.room.VocableDatabase
import com.switch2connect.aac.settings.AddUpdateCategoryViewModel
import com.switch2connect.aac.settings.EditCategoriesViewModel
import com.switch2connect.aac.settings.EditCategoryMenuViewModel
import com.switch2connect.aac.settings.EditCategoryPhrasesViewModel
import com.switch2connect.aac.settings.customcategories.CustomCategoryPhraseViewModel
import com.switch2connect.aac.settings.selectionmode.SelectionModeViewModel
import com.switch2connect.aac.splash.SplashActivity
import com.switch2connect.aac.splash.SplashViewModel
import com.switch2connect.aac.eyegazetracking.EyeGazeTrackingViewModel
import com.switch2connect.aac.utils.DateProvider
import com.switch2connect.aac.utils.EyeGazePermissions
import com.switch2connect.aac.utils.EyeGazeTrackingManager
import com.switch2connect.aac.utils.FaceTrackingManager
import com.switch2connect.aac.utils.FaceTrackingPermissions
import com.switch2connect.aac.utils.IEyeGazePermissions
import com.switch2connect.aac.utils.IFaceTrackingPermissions
import com.switch2connect.aac.utils.ILocalizedResourceUtility
import com.switch2connect.aac.utils.IVocableSharedPreferences
import com.switch2connect.aac.utils.IdlingResourceContainer
import com.switch2connect.aac.utils.IdlingResourceContainerImpl
import com.switch2connect.aac.utils.JavaDateProvider
import com.switch2connect.aac.utils.RandomUUIDProvider
import com.switch2connect.aac.utils.UUIDProvider
import com.switch2connect.aac.utils.VocableEnvironment
import com.switch2connect.aac.utils.VocableEnvironmentImpl
import com.switch2connect.aac.utils.VocableSharedPreferences
import com.switch2connect.aac.utils.locale.JavaLocaleProvider
import com.switch2connect.aac.utils.locale.LocaleProvider
import com.switch2connect.aac.utils.locale.LocalizedResourceUtility
import com.switch2connect.aac.utils.permissions.ActivityPermissionRegisterForLaunch
import com.switch2connect.aac.utils.permissions.ActivityPermissionsChecker
import com.switch2connect.aac.utils.permissions.ActivityPermissionsRationaleDialogShower
import com.switch2connect.aac.utils.permissions.PermissionRequester
import com.switch2connect.aac.utils.permissions.PermissionsChecker
import com.switch2connect.aac.utils.permissions.PermissionsRationaleDialogShower
import org.koin.android.ext.koin.androidContext
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.core.qualifier.named
import org.koin.dsl.bind
import org.koin.dsl.module


val vocableKoinModule = module {

    scope<SplashActivity> {
        viewModel { SplashViewModel(get(), get(), get(named<SplashViewModel>())) }
    }

    scope<MainActivity> {
        scoped {
            FaceTrackingManager(get(), get())
        }
        scoped {
            EyeGazeTrackingManager(get(), get())
        }
        scoped<PermissionsRationaleDialogShower> {
            ActivityPermissionsRationaleDialogShower(get())
        }
        scoped<PermissionRequester> {
            ActivityPermissionRegisterForLaunch(get())
        }
        scoped<PermissionsChecker> {
            ActivityPermissionsChecker(get())
        }
        scoped<IFaceTrackingPermissions> {
            FaceTrackingPermissions(get(), androidContext().packageName, get(), get(), get())
        }
        scoped<IEyeGazePermissions> {
            EyeGazePermissions(get(), androidContext().packageName, get(), get(), get())
        }
        viewModel { FaceTrackingViewModel(get()) }
        viewModel { EyeGazeTrackingViewModel(get()) }
        viewModel { SelectionModeViewModel(get(), get(), get()) }
    }

    single<IdlingResourceContainer>(named<SplashViewModel>()) { IdlingResourceContainerImpl() }
    single<IdlingResourceContainer>(named<PresetsViewModel>()) { IdlingResourceContainerImpl() }
    single { VocableSharedPreferences() } bind IVocableSharedPreferences::class
    single {
        LegacyCategoriesAndPhrasesRepository(
            get(),
            get()
        )
    } bind ILegacyCategoriesAndPhrasesRepository::class
    single { Moshi.Builder().add(KotlinJsonAdapterFactory()).build() }
    single { LocalizedResourceUtility(androidContext()) } bind ILocalizedResourceUtility::class
    single { CategoriesUseCase(get(), get(), get(), get(), get()) } bind ICategoriesUseCase::class
    single { PhrasesUseCase(get(), get(), get(), get(), get(), get()) } bind IPhrasesUseCase::class
    single { RandomUUIDProvider() } bind UUIDProvider::class
    single { JavaDateProvider() } bind DateProvider::class
    single { JavaLocaleProvider() } bind LocaleProvider::class
    single { RoomStoredCategoriesRepository(get()) } bind StoredCategoriesRepository::class
    single { RoomPresetCategoriesRepository(get()) } bind PresetCategoriesRepository::class
    single { RoomStoredPhrasesRepository(get(), get()) } bind StoredPhrasesRepository::class
    single { RoomPresetPhrasesRepository(get(), get()) } bind PresetPhrasesRepository::class
    single { VocableDatabase.createVocableDatabase(get()) }
    single { get<VocableDatabase>().presetPhrasesDao() }
    single<VocableEnvironment> { VocableEnvironmentImpl() }
    viewModel { PresetsViewModel(get(), get(), get(named<PresetsViewModel>()), get()) }
    viewModel { EditCategoriesViewModel(get()) }
    viewModel { EditCategoryPhrasesViewModel(get(), get(), get()) }
    viewModel { AddUpdateCategoryViewModel(get(), get(), get()) }
    viewModel { EditCategoryMenuViewModel(get()) }
    viewModel { CustomCategoryPhraseViewModel(get()) }
}