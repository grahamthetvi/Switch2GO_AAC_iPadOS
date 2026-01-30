package com.switch2go.aac

import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import com.switch2go.aac.facetracking.FaceTrackingViewModel
import com.switch2go.aac.presets.ILegacyCategoriesAndPhrasesRepository
import com.switch2go.aac.presets.LegacyCategoriesAndPhrasesRepository
import com.switch2go.aac.presets.PresetCategoriesRepository
import com.switch2go.aac.presets.PresetsViewModel
import com.switch2go.aac.presets.RoomPresetCategoriesRepository
import com.switch2go.aac.room.PresetPhrasesRepository
import com.switch2go.aac.room.RoomPresetPhrasesRepository
import com.switch2go.aac.room.RoomStoredCategoriesRepository
import com.switch2go.aac.room.RoomStoredPhrasesRepository
import com.switch2go.aac.room.StoredCategoriesRepository
import com.switch2go.aac.room.StoredPhrasesRepository
import com.switch2go.aac.room.VocableDatabase
import com.switch2go.aac.settings.AddUpdateCategoryViewModel
import com.switch2go.aac.settings.EditCategoriesViewModel
import com.switch2go.aac.settings.EditCategoryMenuViewModel
import com.switch2go.aac.settings.EditCategoryPhrasesViewModel
import com.switch2go.aac.settings.customcategories.CustomCategoryPhraseViewModel
import com.switch2go.aac.settings.selectionmode.SelectionModeViewModel
import com.switch2go.aac.splash.SplashActivity
import com.switch2go.aac.splash.SplashViewModel
import com.switch2go.aac.eyegazetracking.EyeGazeTrackingViewModel
import com.switch2go.aac.utils.DateProvider
import com.switch2go.aac.utils.EyeGazePermissions
import com.switch2go.aac.utils.EyeGazeTrackingManager
import com.switch2go.aac.utils.FaceTrackingManager
import com.switch2go.aac.utils.FaceTrackingPermissions
import com.switch2go.aac.utils.IEyeGazePermissions
import com.switch2go.aac.utils.IFaceTrackingPermissions
import com.switch2go.aac.utils.ILocalizedResourceUtility
import com.switch2go.aac.utils.ISwitch2GOSharedPreferences
import com.switch2go.aac.utils.IdlingResourceContainer
import com.switch2go.aac.utils.IdlingResourceContainerImpl
import com.switch2go.aac.utils.JavaDateProvider
import com.switch2go.aac.utils.RandomUUIDProvider
import com.switch2go.aac.utils.UUIDProvider
import com.switch2go.aac.utils.Switch2GOEnvironment
import com.switch2go.aac.utils.Switch2GOEnvironmentImpl
import com.switch2go.aac.utils.Switch2GOSharedPreferences
import com.switch2go.aac.utils.locale.JavaLocaleProvider
import com.switch2go.aac.utils.locale.LocaleProvider
import com.switch2go.aac.utils.locale.LocalizedResourceUtility
import com.switch2go.aac.utils.permissions.ActivityPermissionRegisterForLaunch
import com.switch2go.aac.utils.permissions.ActivityPermissionsChecker
import com.switch2go.aac.utils.permissions.ActivityPermissionsRationaleDialogShower
import com.switch2go.aac.utils.permissions.PermissionRequester
import com.switch2go.aac.utils.permissions.PermissionsChecker
import com.switch2go.aac.utils.permissions.PermissionsRationaleDialogShower
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
    single { Switch2GOSharedPreferences() } bind ISwitch2GOSharedPreferences::class
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
    single<Switch2GOEnvironment> { Switch2GOEnvironmentImpl() }
    viewModel { PresetsViewModel(get(), get(), get(named<PresetsViewModel>()), get()) }
    viewModel { EditCategoriesViewModel(get()) }
    viewModel { EditCategoryPhrasesViewModel(get(), get(), get()) }
    viewModel { AddUpdateCategoryViewModel(get(), get(), get()) }
    viewModel { EditCategoryMenuViewModel(get()) }
    viewModel { CustomCategoryPhraseViewModel(get()) }
}