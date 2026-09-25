import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpException,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { AskCommunityService } from './ask-community.service.js';
import { AskService, type AskEvent } from './ask.service.js';
import { AnswerDto } from './dto/answer.dto.js';
import { AskDto } from './dto/ask.dto.js';
import { NearbyQueryDto } from './dto/nearby-query.dto.js';

@Controller('ask')
@UseGuards(JwtAuthGuard)
export class AskController {
  /** Answers are expensive (a local model run), so one at a time per user. */
  private readonly inFlight = new Set<string>();

  constructor(
    private readonly askService: AskService,
    private readonly community: AskCommunityService,
  ) {}

  /** The community feed: questions recently asked around here. */
  @Get('recent')
  recent(@Query() query: NearbyQueryDto) {
    return this.community.recent(query.lat !== undefined && query.lng !== undefined ? { lat: query.lat, lng: query.lng } : null);
  }

  @Get('questions/:id')
  question(@Req() request: AuthedRequest, @Param('id', ParseUUIDPipe) id: string) {
    return this.community.detail(id, request.userId);
  }

  @Post('questions/:id/answers')
  answer(@Req() request: AuthedRequest, @Param('id', ParseUUIDPipe) id: string, @Body() dto: AnswerDto) {
    return this.community.answer(id, request.userId, dto.body);
  }

  @Delete('questions/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Req() request: AuthedRequest, @Param('id', ParseUUIDPipe) id: string) {
    return this.community.remove(id, request.userId);
  }

  /**
   * Streams the answer as NDJSON (one {@link AskEvent} per line) so the app
   * can show progress, sources, and the answer as it's written.
   */
  @Post()
  async ask(@Req() request: AuthedRequest, @Body() dto: AskDto, @Res() response: Response) {
    const userId = request.userId;
    if (this.inFlight.has(userId)) {
      throw new HttpException('Already answering one of your questions', HttpStatus.TOO_MANY_REQUESTS);
    }
    this.inFlight.add(userId);

    const abort = new AbortController();
    response.on('close', () => abort.abort());
    response.status(200).setHeader('Content-Type', 'application/x-ndjson');
    response.setHeader('Cache-Control', 'no-cache');
    response.flushHeaders();
    const emit = (event: AskEvent) => {
      if (!response.writableEnded) response.write(`${JSON.stringify(event)}\n`);
    };

    const location = dto.lat !== undefined && dto.lng !== undefined ? { lat: dto.lat, lng: dto.lng } : null;
    try {
      await this.askService.answer(userId, dto.question.trim(), location, emit, abort.signal);
    } catch (error) {
      if (!abort.signal.aborted) {
        emit({ type: 'error', message: "Couldn't get an answer right now. Try again in a moment." });
        console.error('Ask HERE failed', error);
      }
    } finally {
      this.inFlight.delete(userId);
      response.end();
    }
  }
}
