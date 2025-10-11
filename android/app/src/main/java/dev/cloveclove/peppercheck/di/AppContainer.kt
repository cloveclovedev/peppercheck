package dev.cloveclove.peppercheck.di

import android.content.ContentResolver
import dev.cloveclove.peppercheck.BuildConfig
import dev.cloveclove.peppercheck.repository.AuthRepository
import dev.cloveclove.peppercheck.repository.JudgementRepository
import dev.cloveclove.peppercheck.repository.ProfileRepository
import dev.cloveclove.peppercheck.repository.R2FileUploadRepository
import dev.cloveclove.peppercheck.domain.rating.RatingRepository
import dev.cloveclove.peppercheck.repository.ApiRatingRepository
import dev.cloveclove.peppercheck.repository.RefereeAvailableTimeSlotRepository
import dev.cloveclove.peppercheck.repository.TaskEvidenceRepository
import dev.cloveclove.peppercheck.repository.TaskRefereeRequestRepository
import dev.cloveclove.peppercheck.repository.TaskRepository
import dev.cloveclove.peppercheck.domain.home.GetHomeTasksUseCase
import dev.cloveclove.peppercheck.domain.task.CreateTaskUseCase
import dev.cloveclove.peppercheck.domain.task.GetTaskDetailsUseCase
import dev.cloveclove.peppercheck.domain.task.SubmitEvidenceUseCase
import dev.cloveclove.peppercheck.domain.task.UpdateJudgementUseCase
import dev.cloveclove.peppercheck.domain.task.UpdateTaskUseCase
import dev.cloveclove.peppercheck.domain.task.ConfirmJudgementUseCase
import dev.cloveclove.peppercheck.domain.task.CloseTaskUseCase
import dev.cloveclove.peppercheck.domain.judgement.ReopenJudgementUseCase
import dev.cloveclove.peppercheck.domain.judgement.ConfirmRefereeTimeoutJudgementUseCase
import dev.cloveclove.peppercheck.domain.judgement.ConfirmEvidenceTimeoutFromRefereeUseCase
import dev.cloveclove.peppercheck.domain.rating.SubmitRefereeRatingUseCase
import dev.cloveclove.peppercheck.domain.profile.AddAvailableTimeSlotUseCase
import dev.cloveclove.peppercheck.domain.profile.CreateStripeConnectLinkUseCase
import dev.cloveclove.peppercheck.domain.profile.DeleteAvailableTimeSlotUseCase
import dev.cloveclove.peppercheck.domain.profile.GetUserAvailableTimeSlotsUseCase
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

/**
 * アプリケーション全体で共有する依存関係（インスタンス）を管理するコンテナ。
 * これらのインスタンスはシングルトンとして扱われます。
 */
class AppContainer(private val contentResolver: ContentResolver) {

    /**
     * Supabaseクライアントのシングルトンインスタンス。
     * by lazy を使うことで、最初にアクセスされたときに一度だけ初期化されます。
     */
    val supabaseClient: SupabaseClient by lazy {
        createSupabaseClient(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_ANON_KEY
        ) {
            install(Auth)
            install(Postgrest)
            install(Functions)
        }
    }

    /**
     * HttpClientのシングルトンインスタンス。
     * Repository層で統一して使用されます。
     */
    val httpClient: HttpClient by lazy {
        HttpClient(OkHttp) {
            install(ContentNegotiation) {
                json(Json {
                    // APIレスポンスに未知のキーがあってもエラーにしない（必須級）
                    ignoreUnknownKeys = true
                    // 不正な形式のJSONにもある程度寛容になる
                    isLenient = true
                    // デフォルト値のプロパティをJSONに含めない（PATCHリクエストで特に重要）
                    encodeDefaults = false
                    // デバッグビルドの時だけ、ログが見やすいようにJSONを整形する
                    prettyPrint = BuildConfig.DEBUG
                })
            }
        }
    }

    // AuthRepositoryは他のRepositoryで使用されるため最初に定義
    val authRepository: AuthRepository by lazy {
        AuthRepository(supabaseClient)
    }

    // 各Repositoryのシングルトンインスタンス
    val taskRepository: TaskRepository by lazy {
        TaskRepository(httpClient, authRepository)
    }

    val profileRepository: ProfileRepository by lazy {
        ProfileRepository(httpClient, authRepository)
    }

    val taskEvidenceRepository: TaskEvidenceRepository by lazy {
        TaskEvidenceRepository(httpClient, authRepository)
    }
    
    val r2FileUploadRepository: R2FileUploadRepository by lazy {
        R2FileUploadRepository(httpClient, authRepository, contentResolver)
    }

    val judgementRepository: JudgementRepository by lazy {
        JudgementRepository(httpClient, authRepository)
    }

    val taskRefereeRequestRepository: TaskRefereeRequestRepository by lazy {
        TaskRefereeRequestRepository(httpClient, authRepository)
    }

    val refereeAvailableTimeSlotRepository: RefereeAvailableTimeSlotRepository by lazy {
        RefereeAvailableTimeSlotRepository(httpClient, authRepository)
    }

    val ratingRepository: RatingRepository by lazy {
        ApiRatingRepository(httpClient, authRepository)
    }

    // Use Cases
    val getHomeTasksUseCase: GetHomeTasksUseCase by lazy {
        GetHomeTasksUseCase(taskRepository)
    }

    val createTaskUseCase: CreateTaskUseCase by lazy {
        CreateTaskUseCase(taskRepository, taskRefereeRequestRepository)
    }

    // --- ProfileScreenで使うUseCaseを追加 ---
    val getUserAvailableTimeSlotsUseCase: GetUserAvailableTimeSlotsUseCase by lazy {
        GetUserAvailableTimeSlotsUseCase(refereeAvailableTimeSlotRepository)
    }
    
    val addAvailableTimeSlotUseCase: AddAvailableTimeSlotUseCase by lazy {
        AddAvailableTimeSlotUseCase(refereeAvailableTimeSlotRepository)
    }

    val deleteAvailableTimeSlotUseCase: DeleteAvailableTimeSlotUseCase by lazy {
        DeleteAvailableTimeSlotUseCase(refereeAvailableTimeSlotRepository)
    }
    
    val createStripeConnectLinkUseCase: CreateStripeConnectLinkUseCase by lazy {
        CreateStripeConnectLinkUseCase(profileRepository)
    }

    val getTaskDetailsUseCase: GetTaskDetailsUseCase by lazy {
        GetTaskDetailsUseCase(taskRepository, taskEvidenceRepository, judgementRepository, taskRefereeRequestRepository, ratingRepository, authRepository)
    }
    
    val updateTaskUseCase: UpdateTaskUseCase by lazy {
        UpdateTaskUseCase(taskRepository, taskRefereeRequestRepository)
    }

    val submitEvidenceUseCase: SubmitEvidenceUseCase by lazy {
        SubmitEvidenceUseCase(taskEvidenceRepository, r2FileUploadRepository, taskRepository)
    }

    val updateJudgementUseCase: UpdateJudgementUseCase by lazy {
        UpdateJudgementUseCase(judgementRepository)
    }
    
    val submitRefereeRatingUseCase: SubmitRefereeRatingUseCase by lazy {
        SubmitRefereeRatingUseCase(ratingRepository)
    }
    
    val confirmJudgementUseCase: ConfirmJudgementUseCase by lazy {
        ConfirmJudgementUseCase(judgementRepository)
    }
    
    val closeTaskUseCase: CloseTaskUseCase by lazy {
        CloseTaskUseCase(taskRepository)
    }
    
    val reopenJudgementUseCase: ReopenJudgementUseCase by lazy {
        ReopenJudgementUseCase(judgementRepository)
    }
    
    val confirmRefereeTimeoutJudgementUseCase: ConfirmRefereeTimeoutJudgementUseCase by lazy {
        ConfirmRefereeTimeoutJudgementUseCase(judgementRepository)
    }
    
    val confirmEvidenceTimeoutFromRefereeUseCase: ConfirmEvidenceTimeoutFromRefereeUseCase by lazy {
        ConfirmEvidenceTimeoutFromRefereeUseCase(judgementRepository)
    }
}