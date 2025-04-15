import { CommonModule, isPlatformBrowser } from '@angular/common';
import { Component, Inject, OnDestroy, OnInit, PLATFORM_ID } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { Observable, Subscription, forkJoin, map, tap } from 'rxjs';

import { PlatformType } from 'app/core';
import { CardComponent } from 'app/shared/card';
import { Card } from 'app/shared/card/card';
import { NavigationComponent } from 'app/shared/navigation';
import { PlatformLogoData, PlatformLogoService } from 'app/shared/platform-logo';
import { TemplateService } from 'app/shared/template';

@Component({
  selector: 'mst-template-gallery',
  imports: [CommonModule, ReactiveFormsModule, CardComponent, NavigationComponent],
  templateUrl: './template-gallery.component.html',
  styleUrl: './template-gallery.component.scss',
  standalone: true
})
export class TemplateGalleryComponent implements OnInit, OnDestroy {
  public templates$!: Observable<Card[]>;

  public searchForm!: FormGroup;

  public isSearch = false;

  private paramSubscription!: Subscription;

  private logos$!: Observable<PlatformLogoData>;

  constructor(
    private router: Router,
    private route: ActivatedRoute,
    private fb: FormBuilder,
    private templateService: TemplateService,
    private platformLogoService: PlatformLogoService,
    @Inject(PLATFORM_ID) private platformId: Object
  ) {}

  public ngOnInit(): void {
    this.initializeSearchForm();
    this.subscribeToRouteParams();
    this.setupMessageListener();
  }

  public ngOnDestroy(): void {
    this.paramSubscription.unsubscribe();
    this.removeMessageListener();
  }

  public onSearch(): void {
    const searchTerm = this.searchForm.value.searchTerm;
    this.templates$ = this.getTemplatesWithLogos(this.templateService.search(searchTerm));
    this.isSearch = !!searchTerm;
    this.router.navigate(['/all']);
  }

  private initializeSearchForm(): void {
    this.searchForm = this.fb.group({
      searchTerm: ['']
    });
  }

  private subscribeToRouteParams(): void {
    this.paramSubscription = this.route.paramMap.subscribe(params => {
      const type = params.get('type') ?? 'all';
      const templateObs$ = this.templateService.filterTemplatesByPlatformType(type as PlatformType);

      this.logos$ = this.platformLogoService.getLogoUrls();
      this.templates$ = this.getTemplatesWithLogos(templateObs$);
    });
  }

  private getTemplatesWithLogos(templateObs$: Observable<any>): Observable<Card[]> {
    return forkJoin({
      templates: templateObs$,
      logos: this.logos$
    })
      .pipe(
        tap(() => (this.isSearch = false)),
        map(({ templates, logos }) =>
          templates.map(item => ({
            cardLogo: item.logo,
            title: item.name,
            description: item.description,
            detailsRoute: `/template/${item.id}`,
            supportedPlatforms: item.supportedPlatforms.map(platform => ({
              platformType: platform,
              imageUrl: logos[item.platformType] ?? null
            }))
          }))
        )
      );
  }

  private setupMessageListener(): void {
    if (isPlatformBrowser(this.platformId)) {
      window.addEventListener('message', this.handleMessage.bind(this), false);
    }
  }

  private removeMessageListener(): void {
    if (isPlatformBrowser(this.platformId)) {
      window.removeEventListener('message', this.handleMessage.bind(this), false);
    }
  }

  private handleMessage(event: MessageEvent): void {
    const originUrl = event.data.originUrl;

    if (typeof originUrl === 'string') {
      sessionStorage.setItem('referrerUrl', originUrl);
    }
  }
}
