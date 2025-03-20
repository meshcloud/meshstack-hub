import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { Observable } from 'rxjs';
import { PlatformType, Template } from '../../core';
import { CardComponent } from '../../shared/card/card.component';
import { TemplateService } from '../../shared/template';

@Component({
  selector: 'app-template-grid',
  imports: [CommonModule, CardComponent],
  templateUrl: './template-grid.component.html',
  styleUrl: './template-grid.component.scss',
  standalone: true
})
export class TemplateGridComponent implements OnInit {

  public templates$!: Observable<Template[]>;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService
  ) {}

  public ngOnInit(): void {
    this.route.paramMap.subscribe(params => {
      const type = params.get('type')?.toLocaleUpperCase() as PlatformType || 'ALL';
      this.templates$ =this.templateService.filterTemplatesByPlatformType(type);
    });
  }

}
